import Darwin
import Foundation
import ExtensionFoundation
import Synchronization
import XPC

@available(iOS 26.0, *)
@main
struct ZNMemoryHelperExtension: AppExtension {
    @AppExtensionPoint.Bind
    var boundExtensionPoint: AppExtensionPoint {
        #if DEBUG
        AppExtensionPoint.Identifier(host: "com.kdt.livecontainer.AAAAA11111", name: "ZNMemoryHelper")
        #else
        AppExtensionPoint.Identifier(host: "com.kdt.livecontainer", name: "ZNMemoryHelper")
        #endif
    }
    var configuration: some AppExtensionConfiguration {
        ConnectionHandler(onSessionRequest: { request in request.accept { _ in MemoryPeer() } })
    }
}

@available(iOS 26.0, *)
private final class MemoryPeer: XPCPeerHandler {
    private let allocation = Mutex<vm_address_t?>(nil)
    deinit { _ = releaseAllocation() }

    func handleIncomingRequest(_ message: XPCDictionary) -> XPCDictionary? {
        var reply = XPCDictionary()
        reply["helperStage"] = "request received"
        do {
            switch message["operation", as: String.self] {
            case "identify":
                reply["pid"] = getpid()
                reply["helperStage"] = "identify reply prepared"
            case "allocate":
                reply["helperStage"] = "allocation request received"
                let region = try allocate()
                reply["region"] = region
                reply["helperStage"] = "vm_allocate succeeded; xpc_shmem_create succeeded; marker initialized; shared-memory reply prepared"
            case "release":
                let result = releaseAllocation()
                guard result == KERN_SUCCESS else {
                    let underlying = NSError(domain: NSMachErrorDomain, code: Int(result), userInfo: [NSLocalizedDescriptionKey: "vm_deallocate returned \(result)."])
                    throw NSError(domain: "ZNMemoryHelper", code: 4, userInfo: [NSLocalizedDescriptionKey: "The helper could not release its 128 MiB allocation.", NSUnderlyingErrorKey: underlying])
                }
                reply["released"] = true
            default:
                throw NSError(domain: "ZNMemoryHelper.Request", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported helper request."])
            }
        } catch {
            let nsError = error as NSError
            reply["error"] = nsError.localizedDescription
            reply["errorDomain"] = nsError.domain
            reply["errorCode"] = Int64(nsError.code)
            if let stage = nsError.userInfo["ZNMemoryHelperStage"] as? String {
                reply["helperStage"] = stage
            } else {
                reply["helperStage"] = "request failed: \(nsError.domain) (\(nsError.code))"
            }
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                reply["underlyingError"] = "\(underlying.domain) (\(underlying.code)): \(underlying.localizedDescription)"
            }
        }
        return reply
    }

    private func releaseAllocation() -> kern_return_t {
        allocation.withLock { address in
            guard let base = address else { return KERN_SUCCESS }
            let size: vm_size_t = 128 * 1024 * 1024
            let result = vm_deallocate(mach_task_self_, base, size)
            if result == KERN_SUCCESS {
                address = nil
            }
            return result
        }
    }

    private func allocate() throws -> xpc_object_t {
        try allocation.withLock { address in
            guard address == nil else {
                throw NSError(domain: "ZNMemoryHelper", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "An allocation is already active.",
                    "ZNMemoryHelperStage": "allocation rejected: an earlier allocation is still active"
                ])
            }
            let size: vm_size_t = 128 * 1024 * 1024
            var base: vm_address_t = 0
            let allocationResult = vm_allocate(mach_task_self_, &base, size, VM_FLAGS_ANYWHERE)
            guard allocationResult == KERN_SUCCESS else {
                let underlying = NSError(domain: NSMachErrorDomain, code: Int(allocationResult), userInfo: [NSLocalizedDescriptionKey: "vm_allocate returned \(allocationResult)."])
                throw NSError(domain: "ZNMemoryHelper", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "The helper could not allocate the fixed 128 MiB test region.",
                    "ZNMemoryHelperStage": "vm_allocate failed (\(allocationResult))",
                    NSUnderlyingErrorKey: underlying
                ])
            }
            guard let pointer = UnsafeMutableRawPointer(bitPattern: UInt(base)), let shared = mlx_create_shared_memory(pointer, Int(size)) else {
                let releaseResult = vm_deallocate(mach_task_self_, base, size)
                var info: [String: Any] = [
                    NSLocalizedDescriptionKey: "xpc_shmem_create failed to export the fixed 128 MiB region.",
                    "ZNMemoryHelperStage": "vm_allocate succeeded; xpc_shmem_create failed"
                ]
                if releaseResult != KERN_SUCCESS {
                    info[NSUnderlyingErrorKey] = NSError(domain: NSMachErrorDomain, code: Int(releaseResult), userInfo: [NSLocalizedDescriptionKey: "Cleanup vm_deallocate returned \(releaseResult)."])
                }
                throw NSError(domain: "ZNMemoryHelper", code: 3, userInfo: info)
            }
            pointer.initializeMemory(as: UInt8.self, repeating: 0, count: Int(size))
            pointer.storeBytes(of: UInt64(0x5A4E4D454D4C4142), as: UInt64.self)
            address = base
            return shared
        }
    }
}
