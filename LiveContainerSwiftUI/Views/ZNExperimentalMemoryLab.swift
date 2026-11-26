import Darwin
import ExtensionFoundation
import SwiftUI
import XPC

@available(iOS 26.0, *)
extension AppExtensionPoint {
    @Definition
    static var znMemoryHelper: AppExtensionPoint {
        Name("ZNMemoryHelper")
        EnhancedSecurity()
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

    func runDiagnostic() {
        guard helperEnabled else { status = "Enable Memory Helper to run the diagnostic."; return }
        guard os_proc_available_memory() >= 768 * 1024 * 1024 else { status = "Stopped. Process headroom is below 768 MiB."; return }
        guard ProcessInfo.processInfo.thermalState.rawValue < 3 else { status = "Stopped because the device is thermally stressed."; return }
        running = true
        Task { defer { running = false }; await diagnostic() }
    }

    private func diagnostic() async {
        do {
            let monitor = try await AppExtensionPoint.Monitor(appExtensionPoint: .znMemoryHelper)
            guard let identity = monitor.identities.first else { status = "Memory Helper extension is unavailable. Check that SideStore kept the embedded extension."; return }
            let process = try await AppExtensionProcess(configuration: .init(appExtensionIdentity: identity))
            defer { process.invalidate() }
            let session = try process.makeXPCSession()
            try session.activate()
            defer { session.cancel(reason: "Memory Lab diagnostic finished") }
            let pidReply = try await request("identify", session: session)
            guard let helperPID = pidReply["pid", as: pid_t.self], helperPID > 0, helperPID != getpid() else { throw LabError("Helper did not report a separate PID.") }
            guard os_proc_available_memory() >= 768 * 1024 * 1024 else { throw LabError("Stopped before allocation because process headroom fell below 768 MiB.") }
            var allocationRequest = XPCDictionary(); allocationRequest["operation"] = "allocate"
            let regionReply = try await send(allocationRequest, session: session)
            guard let region = regionReply["region", as: XPC_TYPE_SHMEM] else { throw LabError("Helper returned no shared memory region.") }
            defer { var release = XPCDictionary(); release["operation"] = "release"; session.send(message: release) { _ in } }
            var scratch: UnsafeMutableRawPointer?
            let mappedSize = xpc_shmem_map(region, &scratch)
            guard let scratch, mappedSize == 128 * 1024 * 1024 else { throw LabError("Shared-memory mapping failed or returned the wrong size.") }
            defer { munmap(scratch, mappedSize) }
            let marker = scratch.load(as: UInt64.self)
            let available = os_proc_available_memory()
            status = marker == 0x5A4E4D454D4C4142 ? "Separate helper PID confirmed. 128 MiB shared-memory marker verified." : "Shared-memory marker verification failed."
            report = "Host PID: \(getpid())\nHelper PID: \(helperPID)\nShared region: 128 MiB virtual mapping\nAvailable process headroom after mapping: \(available / 1_048_576) MiB\nThermal state: \(ProcessInfo.processInfo.thermalState.rawValue)\nVerification: \(marker == 0x5A4E4D454D4C4142 ? "passed" : "failed")\nThis diagnostic does not alter or connect to a running game allocator."
        } catch { status = error.localizedDescription }
    }

    private func request(_ operation: String, session: XPCSession) async throws -> XPCDictionary {
        var message = XPCDictionary(); message["operation"] = operation
        return try await send(message, session: session)
    }

    private func send(_ message: XPCDictionary, session: XPCSession) async throws -> XPCDictionary {
        try await withThrowingTaskGroup(of: XPCDictionary.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    session.send(message: message) { result in
                        switch result { case .success(let reply): continuation.resume(returning: reply); case .failure(let error): continuation.resume(throwing: error) }
                    }
                }
            }
            group.addTask { try await Task.sleep(for: .seconds(5)); throw LabError("Memory Helper timed out.") }
            let result = try await group.next()!
            group.cancelAll()
            if let error = result["error", as: String.self] { throw LabError(error) }
            return result
        }
    }

    func exportReport() { UIPasteboard.general.string = report.isEmpty ? status : report }
    func restoreDefaults() { helperEnabled = false; pressureProtection = true; status = "Defaults restored. Helper disabled."; report = "" }
}

@available(iOS 26.0, *)
struct ZNExperimentalMemoryLab: View {
    @StateObject private var model = ZNMemoryLabModel()
    var body: some View {
        Form {
            Section { Toggle("Enable Memory Helper", isOn: $model.helperEnabled); Text(model.status).font(.footnote).foregroundStyle(.secondary) }
            Section("Safe shared-memory test") {
                LabeledContent("Test size", value: "128 MiB")
                Button(model.running ? "Testing…" : "Run shared-memory diagnostic") { model.runDiagnostic() }.disabled(model.running)
                Text("Runs only while reported process headroom is at least 768 MiB. Test memory is released automatically.").font(.footnote)
            }
            Section("Protection") {
                Toggle("Memory Pressure Protection", isOn: $model.pressureProtection)
                Text("Automatic memory release is enabled for this test. No allocation is retained for games.").font(.footnote)
            }
            if !model.report.isEmpty { Section("Diagnostic report") { Text(model.report).font(.system(.caption, design: .monospaced)).textSelection(.enabled); Button("Export Diagnostic Report") { model.exportReport() } } }
            Section { Button("Restore Default Settings", role: .destructive) { model.restoreDefaults() } }
            Section { Text("Experimental. Shared memory is a mapping diagnostic only. Existing NxNative games cannot use this region unless their own allocator is modified. This does not bypass iOS memory limits.").font(.footnote) }
        }.navigationTitle("ZN Experimental Memory Lab")
    }
}

private struct LabError: LocalizedError { let message: String; init(_ message: String) { self.message = message }; var errorDescription: String? { message } }
