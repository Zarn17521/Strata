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
                reply["helperStage"] = "shm_open succeeded; ftruncate succeeded; mmap(MAP_SHARED) succeeded; xpc_shmem_create succeeded; marker initialized; shared-memory reply prepared"
            case "release":
                let result = releaseAllocation()
                guard result == KERN_SUCCESS else {
                    let errorCode = Int32(result)
                    let underlying = NSError(domain: NSPOSIXErrorDomain, code: Int(errorCode), userInfo: [NSLocalizedDescriptionKey: "munmap failed: \(String(cString: strerror(errorCode)))."])
                    throw NSError(domain: "ZNMemoryHelper", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "The helper could not release its 128 MiB shared mapping.",
                        "ZNMemoryHelperStage": "munmap failed (errno \(errorCode))",
                        NSUnderlyingErrorKey: underlying
                    ])
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
            let size = 128 * 1024 * 1024
            guard let pointer = UnsafeMutableRawPointer(bitPattern: UInt(base)) else {
                return KERN_INVALID_ADDRESS
            }
            guard munmap(pointer, size) == 0 else {
                let errorCode = errno
                return kern_return_t(errorCode == 0 ? EIO : errorCode)
            }
            address = nil
            return KERN_SUCCESS
        }
    }

    private func allocate() throws -> xpc_object_t {
        try allocation.withLock { address in
            guard address == nil else {
                throw NSError(domain: "ZNMemoryHelper", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "A shared-memory allocation is already active.",
                    "ZNMemoryHelperStage": "allocation rejected: an earlier mapping is still active"
                ])
            }

            let size = 128 * 1024 * 1024
            let name = "/zn-memory-lab-\(UUID().uuidString)"
            let descriptor = name.withCString {
                shm_open($0, O_CREAT | O_EXCL | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
            }
            guard descriptor >= 0 else {
                throw posixFailure(
                    "shm_open",
                    stage: "shm_open failed"
                )
            }
            defer {
                _ = close(descriptor)
                name.withCString { _ = shm_unlink($0) }
            }

            guard ftruncate(descriptor, off_t(size)) == 0 else {
                throw posixFailure(
                    "ftruncate",
                    stage: "shm_open succeeded; ftruncate failed"
                )
            }

            let mapping = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, descriptor, 0)
            guard let pointer = mapping, pointer != MAP_FAILED else {
                throw posixFailure(
                    "mmap(MAP_SHARED)",
                    stage: "shm_open and ftruncate succeeded; mmap(MAP_SHARED) failed"
                )
            }

            var mappingOwnedByHelper = true
            defer {
                if mappingOwnedByHelper {
                    _ = munmap(pointer, size)
                }
            }

            pointer.initializeMemory(as: UInt8.self, repeating: 0, count: size)
            pointer.storeBytes(of: UInt64(0x5A4E4D454D4C4142), as: UInt64.self)

            guard let shared = mlx_create_shared_memory(pointer, size) else {
                throw NSError(domain: "ZNMemoryHelper", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "xpc_shmem_create failed to export the MAP_SHARED 128 MiB region.",
                    "ZNMemoryHelperStage": "shm_open, ftruncate, and mmap(MAP_SHARED) succeeded; xpc_shmem_create returned nil"
                ])
            }

            address = vm_address_t(UInt(bitPattern: pointer))
            mappingOwnedByHelper = false
            return shared
        }
    }

    private func posixFailure(_ operation: String, stage: String) -> NSError {
        let errorCode = errno
        let underlying = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(errorCode),
            userInfo: [NSLocalizedDescriptionKey: "\(operation) failed: \(String(cString: strerror(errorCode)))."]
        )
        return NSError(
            domain: "ZNMemoryHelper",
            code: 5,
            userInfo: [
                NSLocalizedDescriptionKey: "The helper could not create the shared 128 MiB test mapping.",
                "ZNMemoryHelperStage": stage,
                NSUnderlyingErrorKey: underlying
            ]
        )
    }
}
