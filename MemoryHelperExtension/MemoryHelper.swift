import Darwin
import ExtensionFoundation
import Synchronization
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
@main
struct ZNMemoryHelperExtension: AppExtension {
    @AppExtensionPoint.Bind
    var boundExtensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(host: Bundle.main.infoDictionary?["ZNMemoryHelperHostBundleIdentifier"] as? String ?? "com.kdt.livecontainer", name: "ZNMemoryHelper")
    }
    var configuration: some AppExtensionConfiguration {
        ConnectionHandler(onSessionRequest: { request in request.accept { _ in MemoryPeer() } })
    }
}

@available(iOS 26.0, *)
private final class MemoryPeer: XPCPeerHandler {
    private let allocation = Mutex<vm_address_t?>(nil)
    deinit { releaseAllocation() }

    func handleIncomingRequest(_ message: XPCDictionary) -> XPCDictionary? {
        var reply = XPCDictionary()
        switch message["operation", as: String.self] {
        case "identify": reply["pid"] = getpid()
        case "allocate":
            do { reply["region"] = try allocate() }
            catch { reply["error"] = error.localizedDescription }
        case "release": releaseAllocation(); reply["released"] = true
        default: reply["error"] = "Unsupported request."
        }
        return reply
    }

    private func releaseAllocation() {
        allocation.withLock { address in
            if let base = address { vm_deallocate(mach_task_self_, base, 128 * 1024 * 1024); address = nil }
        }
    }

    private func allocate() throws -> xpc_object_t {
        try allocation.withLock { address in
            guard address == nil else { throw NSError(domain: "ZNMemoryHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "An allocation is already active."]) }
            let size = 128 * 1024 * 1024
            var base: vm_address_t = 0
            guard vm_allocate(mach_task_self_, &base, size, VM_FLAGS_ANYWHERE) == KERN_SUCCESS else {
                throw NSError(domain: "ZNMemoryHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Helper allocation failed."])
            }
            guard let pointer = UnsafeMutableRawPointer(bitPattern: UInt(base)), let shared = mlx_create_shared_memory(pointer, size) else {
                vm_deallocate(mach_task_self_, base, size)
                throw NSError(domain: "ZNMemoryHelper", code: 3, userInfo: [NSLocalizedDescriptionKey: "Shared memory export failed."])
            }
            pointer.initializeMemory(as: UInt8.self, repeating: 0, count: size)
            pointer.storeBytes(of: UInt64(0x5A4E4D454D4C4142), as: UInt64.self)
            address = base
            return shared
        }
    }
}
