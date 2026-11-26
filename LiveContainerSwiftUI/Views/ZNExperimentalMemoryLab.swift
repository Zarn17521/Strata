import Darwin
import Dispatch
import ExtensionFoundation
import SwiftUI
import UIKit
import XPC

private enum ZNMemoryLabFailure {
    static func make(_ message: String, domain: String = "ZNMemoryLab", code: Int, underlying: Error? = nil, reason: String? = nil) -> NSError {
        var info: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let reason { info[NSLocalizedFailureReasonErrorKey] = reason }
        if let underlying { info[NSUnderlyingErrorKey] = underlying as NSError }
        return NSError(domain: domain, code: code, userInfo: info)
    }
}

private final class ZNXPCRequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<XPCDictionary, Error>?

    init(_ continuation: CheckedContinuation<XPCDictionary, Error>) {
        self.continuation = continuation
    }

    @discardableResult
    func finish(_ result: Result<XPCDictionary, Error>) -> Bool {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        guard let continuation else { return false }
        switch result {
        case .success(let reply): continuation.resume(returning: reply)
        case .failure(let error): continuation.resume(throwing: error)
        }
        return true
    }
}

@available(iOS 26.0, *)
@MainActor
final class ZNMemoryLabModel: ObservableObject {
    @AppStorage("ZNMemoryHelperEnabled") var helperEnabled = false
    @AppStorage("ZNMemoryPressureProtection") var pressureProtection = true
    @Published var status = "Experimental helper is disabled."
    @Published var report = ""
    @Published var running = false

    private var expectedHostBundleIdentifier: String {
        #if DEBUG
        "com.kdt.livecontainer.AAAAA11111"
        #else
        "com.kdt.livecontainer"
        #endif
    }

    func runDiagnostic() {
        guard helperEnabled else {
            recordFailure(ZNMemoryLabFailure.make("Enable Memory Helper before running the diagnostic.", code: 1), phase: "Not started")
            return
        }
        guard os_proc_available_memory() >= 768 * 1024 * 1024 else {
            recordFailure(ZNMemoryLabFailure.make("The test stopped before allocation because reported process headroom is below 768 MiB.", code: 2), phase: "Safety check")
            return
        }
        guard ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else {
            recordFailure(ZNMemoryLabFailure.make("The test stopped because the device is thermally stressed.", code: 3), phase: "Safety check")
            return
        }

        running = true
        status = "Checking ExtensionFoundation registration…"
        report = makeReport(phase: "Starting", helperPID: nil, error: nil)
        Task { defer { running = false }; await diagnostic() }
    }

    private func diagnostic() async {
        let actualHostBundleIdentifier = Bundle.main.bundleIdentifier ?? "(unavailable)"
        guard actualHostBundleIdentifier == expectedHostBundleIdentifier else {
            recordFailure(
                ZNMemoryLabFailure.make(
                    "The installed host bundle identifier does not match the helper's compile-time binding.",
                    domain: "ZNMemoryLab.BundleIdentity",
                    code: 10,
                    reason: "Expected \(expectedHostBundleIdentifier); installed app reports \(actualHostBundleIdentifier). SideStore can replace bundle identifiers to match a provisioning profile. The ExtensionFoundation binding must be rebuilt with the final host identifier."
                ),
                phase: "Host identity check"
            )
            return
        }

        var helperPID: pid_t?
        var phase = "Extension point lookup"
        do {
            let point: AppExtensionPoint
            do {
                point = try AppExtensionPoint(identifier: "ZNMemoryHelper")
            } catch {
                throw ZNMemoryLabFailure.make("Could not construct the ZNMemoryHelper extension point.", domain: "ZNMemoryLab.ExtensionPoint", code: 20, underlying: error)
            }

            let monitor: AppExtensionPoint.Monitor
            do {
                monitor = try await AppExtensionPoint.Monitor(appExtensionPoint: point)
            } catch {
                throw ZNMemoryLabFailure.make(
                    "ExtensionFoundation failed while registering or observing ZNMemoryHelper.",
                    domain: "ZNMemoryLab.ExtensionPointMonitor",
                    code: 21,
                    underlying: error,
                    reason: "The host app and extension must both contain generated ExtensionFoundation metadata, and the installed host bundle identifier must match the helper binding."
                )
            }

            guard let identity = monitor.identities.first else {
                throw ZNMemoryLabFailure.make(
                    "No Memory Helper extension was discovered.",
                    domain: "ZNMemoryLab.ExtensionDiscovery",
                    code: 22,
                    reason: "Check that the embedded .appex is present, its provisioning profile allows it, and the .appext registration/binding metadata was generated."
                )
            }

            phase = "Starting helper process"
            let process: AppExtensionProcess
            do {
                process = try AppExtensionProcess(configuration: .init(appExtensionIdentity: identity))
            } catch {
                throw ZNMemoryLabFailure.make("ExtensionFoundation discovered the helper but could not start its process.", domain: "ZNMemoryLab.ExtensionProcess", code: 23, underlying: error)
            }
            defer { process.invalidate() }

            let session = try process.makeXPCSession()
            try session.activate()
            defer { session.cancel(reason: "Memory Lab diagnostic finished") }

            phase = "Verifying helper PID"
            let pidReply = try await request("identify", session: session)
            guard let reportedPID = pidReply["pid", as: pid_t.self], reportedPID > 0, reportedPID != getpid() else {
                throw ZNMemoryLabFailure.make("The helper did not report a distinct process identifier.", domain: "ZNMemoryLab.ProcessIdentity", code: 24)
            }
            helperPID = reportedPID

            guard os_proc_available_memory() >= 768 * 1024 * 1024 else {
                throw ZNMemoryLabFailure.make("The test stopped before allocation because process headroom fell below 768 MiB.", domain: "ZNMemoryLab.MemoryPressure", code: 25)
            }
            guard ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else {
                throw ZNMemoryLabFailure.make("The test stopped before allocation because the device entered a serious thermal state.", domain: "ZNMemoryLab.Thermal", code: 26)
            }

            phase = "Allocating and mapping 128 MiB"
            let regionReply = try await request("allocate", session: session)
            guard let region = regionReply["region", as: XPC_TYPE_SHMEM] else {
                throw ZNMemoryLabFailure.make("The helper returned no shared-memory region.", domain: "ZNMemoryLab.SharedMemory", code: 27)
            }

            var scratch: UnsafeMutableRawPointer?
            let mappedSize = xpc_shmem_map(region, &scratch)
            guard let scratch else {
                throw ZNMemoryLabFailure.make("Shared-memory mapping failed or returned a size other than 128 MiB.", domain: "ZNMemoryLab.SharedMemory", code: 28)
            }
            var mappingActive = true
            defer { if mappingActive { munmap(scratch, mappedSize) } }
            guard mappedSize == 128 * 1024 * 1024 else {
                throw ZNMemoryLabFailure.make("Shared-memory mapping returned \(mappedSize) bytes instead of 128 MiB.", domain: "ZNMemoryLab.SharedMemory", code: 29)
            }

            let marker = scratch.load(as: UInt64.self)
            let verified = marker == 0x5A4E4D454D4C4142
            guard munmap(scratch, mappedSize) == 0 else {
                throw ZNMemoryLabFailure.make("The host could not unmap its shared-memory view.", domain: "ZNMemoryLab.SharedMemory", code: 31)
            }
            mappingActive = false
            phase = "Releasing allocation"
            _ = try await request("release", session: session)

            status = verified ? "Separate helper PID confirmed. 128 MiB shared-memory marker verified." : "Shared-memory marker verification failed."
            report = makeReport(phase: "Completed", helperPID: helperPID, error: nil, verification: verified ? "passed" : "failed", mappedSize: mappedSize)
        } catch {
            recordFailure(error, phase: phase, helperPID: helperPID)
        }
    }

    private func request(_ operation: String, session: XPCSession) async throws -> XPCDictionary {
        var message = XPCDictionary()
        message["operation"] = operation
        return try await send(message, session: session)
    }

    private func send(_ message: XPCDictionary, session: XPCSession) async throws -> XPCDictionary {
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<XPCDictionary, Error>) in
            let gate = ZNXPCRequestGate(continuation)
            session.send(message: message) { result in gate.finish(result) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if gate.finish(.failure(ZNMemoryLabFailure.make("Memory Helper request timed out after five seconds.", domain: "ZNMemoryLab.Timeout", code: 30))) {
                    session.cancel(reason: "Memory Helper request timed out")
                }
            }
        }
        if let message = result["error", as: String.self] {
            let domain = result["errorDomain", as: String.self] ?? "ZNMemoryHelper"
            let code = Int(result["errorCode", as: Int64.self] ?? -1)
            var info: [String: Any] = [NSLocalizedDescriptionKey: message]
            if let reason = result["underlyingError", as: String.self] { info[NSLocalizedFailureReasonErrorKey] = reason }
            throw NSError(domain: domain, code: code, userInfo: info)
        }
        return result
    }

    private func recordFailure(_ error: Error, phase: String, helperPID: pid_t? = nil) {
        status = error.localizedDescription
        report = makeReport(phase: phase, helperPID: helperPID, error: error)
    }

    private func makeReport(phase: String, helperPID: pid_t?, error: Error?, verification: String = "not run", mappedSize: Int = 0) -> String {
        let actualHostBundleIdentifier = Bundle.main.bundleIdentifier ?? "(unavailable)"
        let availableMiB = os_proc_available_memory() / 1_048_576
        let thermal = ProcessInfo.processInfo.thermalState
        let extensionMetadata = ((try? FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "appext" }
            .map { $0.path.replacingOccurrences(of: Bundle.main.bundlePath + "/", with: "") }
        let metadataList = extensionMetadata.isEmpty ? "not found in installed host bundle" : extensionMetadata.joined(separator: ", ")
        let errorText = error.map(describeError) ?? "none"

        return """
        ZN Experimental Memory Lab
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        Phase: \(phase)
        Host PID: \(getpid())
        Installed host bundle ID: \(actualHostBundleIdentifier)
        Compiled helper host ID: \(expectedHostBundleIdentifier)
        Host ID matches binding: \(actualHostBundleIdentifier == expectedHostBundleIdentifier)
        Extension point: ZNMemoryHelper
        Host .appext registration metadata: \(metadataList)
        Helper PID: \(helperPID.map { String($0) } ?? "not connected")
        Physical RAM: \(ProcessInfo.processInfo.physicalMemory / 1_048_576) MiB
        Available process memory: \(availableMiB) MiB
        Thermal state: \(thermal)
        Shared-memory mapping: \(mappedSize > 0 ? "\(mappedSize / 1_048_576) MiB" : "not mapped")
        Shared-memory verification: \(verification)
        Helper connection: \(helperPID == nil ? "not established" : "connected")
        Error details:
        \(errorText)

        This diagnostic allocates at most 128 MiB, releases it when the session ends, and does not change iOS memory limits or connect to game allocators.
        """
    }

    private func describeError(_ error: Error) -> String {
        var chain: [String] = []
        var next: NSError? = error as NSError
        var visited = Set<ObjectIdentifier>()
        while let current = next, visited.insert(ObjectIdentifier(current)).inserted {
            var entry = "Domain: \(current.domain); code: \(current.code); description: \(current.localizedDescription)"
            if let reason = current.userInfo[NSLocalizedFailureReasonErrorKey] as? String { entry += "; reason: \(reason)" }
            chain.append(entry)
            next = current.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return chain.isEmpty ? "none" : chain.joined(separator: "\nUnderlying error: ")
    }

    func exportReport() { UIPasteboard.general.string = report.isEmpty ? status : report }
    func restoreDefaults() { helperEnabled = false; pressureProtection = true; status = "Defaults restored. Helper disabled."; report = "" }
}

@available(iOS 26.0, *)
struct ZNExperimentalMemoryLab: View {
    @StateObject private var model = ZNMemoryLabModel()

    var body: some View {
        Form {
            Section {
                Toggle("Enable Memory Helper", isOn: $model.helperEnabled)
                Text(model.status).font(.footnote).foregroundStyle(.secondary)
            }
            Section("Safe shared-memory test") {
                LabeledContent("Test size", value: "128 MiB")
                Button(model.running ? "Testing…" : "Run shared-memory diagnostic") { model.runDiagnostic() }.disabled(model.running)
                Text("Runs only while reported process headroom is at least 768 MiB. Test memory is released automatically.").font(.footnote)
            }
            Section("Protection") {
                Toggle("Memory Pressure Protection", isOn: $model.pressureProtection)
                Text("Automatic memory release is enabled for this test. No allocation is retained for games.").font(.footnote)
            }
            Section("Diagnostic report") {
                if !model.report.isEmpty {
                    Text(model.report).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                } else {
                    Text("A report will be available after the next diagnostic attempt, including if extension discovery fails.").font(.footnote).foregroundStyle(.secondary)
                }
                Button("Export Diagnostic Report") { model.exportReport() }
            }
            Section { Button("Restore Default Settings", role: .destructive) { model.restoreDefaults() } }
            Section { Text("Experimental. Shared memory is a mapping diagnostic only. Existing NxNative games cannot use this region unless their own allocator is modified. This does not bypass iOS memory limits.").font(.footnote) }
        }
        .navigationTitle("ZN Experimental Memory Lab")
    }
}
