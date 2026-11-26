import SwiftUI
import UIKit

// MARK: - Pure Swift RAM Donor (safe progressive allocation)

final class StrataRAMDonorEngine {
    static let shared = StrataRAMDonorEngine()
    
    private var allocations: [UnsafeMutableRawPointer] = []
    private var allocationSizes: [Int] = []
    private let lock = NSLock()
    
    struct Result {
        var physicalRAM: UInt64 = 0
        var osAvailable: UInt64 = 0
        var physFootprint: UInt64 = 0
        var pooledTouched: UInt64 = 0
        var liveDonors: Int = 0
        var pagesVerified: UInt64 = 0
        var mismatches: UInt64 = 0
        var exceedsLimit: Bool = false
        var log: String = ""
    }
    
    func physicalRAM() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        sysctl(&mib, 2, &size, &len, nil, 0)
        return size
    }
    
    func osAvailable() -> UInt64 {
        return UInt64(os_proc_available_memory())
    }
    
    func physFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? info.phys_footprint : 0
    }
    
    func currentStats() -> [String: UInt64] {
        [
            "physicalRAM": physicalRAM(),
            "osAvailable": osAvailable(),
            "physFootprint": physFootprint()
        ]
    }
    
    /// Stop allocating when available headroom drops below this (bytes).
    private let safetyHeadroom: UInt64 = 768 * 1024 * 1024
    private let testLock = NSLock()
    
    private func shouldStop() -> Bool {
        osAvailable() < safetyHeadroom + 128 * 1024 * 1024
    }
    
    func runCeilingTest(targetMB: Int) -> Result {
        testLock.lock()
        defer { releaseAll(); testLock.unlock() }
        var r = Result()
        r.physicalRAM = physicalRAM()
        r.osAvailable = osAvailable()
        var log = "=== Ceiling Test (safe) ===\nTarget: \(targetMB) MB\nOS Available start: \(r.osAvailable / (1024*1024)) MB\n"
        
        let pageSize = Int(getpagesize())
        let chunkSize = 32 * 1024 * 1024  // 32 MB chunks (safer)
        let targetBytes = min(max(targetMB, 0), 2048) * 1024 * 1024
        var allocated = 0
        var mismatches: UInt64 = 0
        
        while allocated < targetBytes {
            if shouldStop() {
                log += "Stopped early (low headroom). Allocated \(allocated / (1024*1024)) MB\n"
                break
            }
            
            let thisChunk = min(chunkSize, targetBytes - allocated)
            guard let ptr = malloc(thisChunk) else {
                log += "malloc failed at \(allocated / (1024*1024)) MB\n"
                break
            }
            
            // Touch pages
            var i = 0
            while i < thisChunk {
                ptr.storeBytes(of: UInt8(truncatingIfNeeded: i / pageSize), toByteOffset: i, as: UInt8.self)
                i += pageSize
            }
            
            for offset in stride(from: 0, to: thisChunk, by: pageSize) {
                if ptr.load(fromByteOffset: offset, as: UInt8.self) != UInt8(truncatingIfNeeded: offset / pageSize) { mismatches += 1 }
            }
            lock.lock()
            allocations.append(ptr)
            allocationSizes.append(thisChunk)
            lock.unlock()
            
            allocated += thisChunk
            let fp = physFootprint()
            log += "+\(thisChunk/(1024*1024)) MB → total \(allocated/(1024*1024)) MB | FP \(fp/(1024*1024)) MB | avail \(osAvailable()/(1024*1024)) MB\n"
        }
        
        r.physFootprint = physFootprint()
        r.pooledTouched = UInt64(allocated)
        r.pagesVerified = UInt64(allocated / max(pageSize, 1))
        r.mismatches = mismatches
        r.exceedsLimit = false
        log += "\nFinal FP: \(r.physFootprint/(1024*1024)) MB | Start OS avail: \(r.osAvailable/(1024*1024)) MB\n"
        log += "Local diagnostic only; allocations automatically released. No bypass established.\n"
        r.log = log
        return r
    }
    
    func runDonorTest(targetMB: Int, donorCount: Int) -> Result {
        testLock.lock()
        defer { releaseAll(); testLock.unlock() }
        var r = Result()
        r.physicalRAM = physicalRAM()
        r.osAvailable = osAvailable()
        var log = "=== Donor Test (safe) ===\nTarget: \(targetMB) MB | Donors: \(donorCount)\nOS Available start: \(r.osAvailable / (1024*1024)) MB\n"
        
        let pageSize = Int(getpagesize())
        let groups = max(1, min(donorCount, 64))
        let perDonor = (min(max(targetMB, 0), 2048) * 1024 * 1024) / groups
        var totalAllocated = 0
        var mismatches: UInt64 = 0
        var successDonors = 0
        
        for d in 0..<groups {
            if shouldStop() {
                log += "Stopped at donor \(d) (low headroom)\n"
                break
            }
            
            // Cap each donor chunk so we don't allocate a huge block at once
            let safeSize = min(perDonor, 128 * 1024 * 1024) // max 128 MB per donor step
            guard safeSize > 0, let ptr = malloc(safeSize) else {
                log += "Donor \(d) malloc failed\n"
                continue
            }
            
            var i = 0
            while i < safeSize {
                ptr.storeBytes(of: UInt8(truncatingIfNeeded: d + i / pageSize), toByteOffset: i, as: UInt8.self)
                i += pageSize
            }
            
            for offset in stride(from: 0, to: safeSize, by: pageSize) {
                if ptr.load(fromByteOffset: offset, as: UInt8.self) != UInt8(truncatingIfNeeded: d + offset / pageSize) { mismatches += 1 }
            }
            lock.lock()
            allocations.append(ptr)
            allocationSizes.append(safeSize)
            lock.unlock()
            
            totalAllocated += safeSize
            successDonors += 1
            log += "Donor \(d): +\(safeSize/(1024*1024)) MB | total \(totalAllocated/(1024*1024)) MB | avail \(osAvailable()/(1024*1024)) MB\n"
        }
        
        r.physFootprint = physFootprint()
        r.pooledTouched = UInt64(totalAllocated)
        r.liveDonors = successDonors
        r.pagesVerified = UInt64(totalAllocated / max(pageSize, 1))
        r.mismatches = mismatches
        r.exceedsLimit = false
        log += "\nFinal FP: \(r.physFootprint/(1024*1024)) MB | Pooled: \(r.pooledTouched/(1024*1024)) MB\n"
        log += "Local diagnostic only; allocations automatically released. No bypass established.\n"
        r.log = log
        return r
    }
    
    func releaseAll() {
        lock.lock()
        for ptr in allocations {
            free(ptr)
        }
        allocations.removeAll()
        allocationSizes.removeAll()
        lock.unlock()
        malloc_zone_pressure_relief(nil, 0)
    }
}

// MARK: - UI

struct StrataRAMDonorView: View {
    @State private var resultLog: String = "Ready. Diagnostic reserves headroom; jetsam remains possible."
    @State private var isRunning = false
    @State private var physicalRAM: String = "—"
    @State private var osAvailable: String = "—"
    @State private var physFootprint: String = "—"
    @State private var pooled: String = "—"
    @State private var donors: String = "0"
    @State private var status: String = "Idle"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GroupBox("Memory Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        row("Physical RAM", physicalRAM)
                        row("Available headroom", osAvailable)
                        row("Footprint / test peak", physFootprint)
                        row("Test bytes touched", pooled)
                        row("Local allocation groups", donors)
                        Text(status)
                            .font(.headline)
                            .foregroundColor(status.contains("EXCEEDS") ? .green : .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(spacing: 12) {
                    Button {
                        runDonorTest()
                    } label: {
                        Label("Run Donor Test (safe)", systemImage: "memorychip")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                    
                    Button {
                        runCeilingTest()
                    } label: {
                        Label("Ceiling Test (safe)", systemImage: "arrow.up.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning)
                    
                    Button {
                        releaseMemory()
                    } label: {
                        Label("Release", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isRunning)
                    
                    Button {
                        shareReport()
                    } label: {
                        Label("Share Report", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                GroupBox("Test Log") {
                    Text(resultLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("RAM Donor")
        .onAppear { refreshStats() }
    }
    
    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).bold()
        }
    }
    
    private func mb(_ bytes: UInt64) -> String {
        String(format: "%.0f MB", Double(bytes) / 1024.0 / 1024.0)
    }
    
    private func refreshStats() {
        let stats = StrataRAMDonorEngine.shared.currentStats()
        physicalRAM = mb(stats["physicalRAM"] ?? 0)
        osAvailable = mb(stats["osAvailable"] ?? 0)
        physFootprint = mb(stats["physFootprint"] ?? 0)
    }
    
    private func runDonorTest() {
        isRunning = true
        status = "Running Donor Test..."
        resultLog = "Starting safe donor test...\n"
        
        // Smaller default: 2 GB across 8 donors (~256 MB each), stop early if low
        DispatchQueue.global(qos: .userInitiated).async {
            let res = StrataRAMDonorEngine.shared.runDonorTest(targetMB: 2048, donorCount: 8)
            DispatchQueue.main.async {
                self.apply(result: res)
                self.isRunning = false
            }
        }
    }
    
    private func runCeilingTest() {
        isRunning = true
        status = "Running Ceiling Test..."
        resultLog = "Starting safe ceiling test...\n"
        
        // 1.5 GB ceiling with early stop
        DispatchQueue.global(qos: .userInitiated).async {
            let res = StrataRAMDonorEngine.shared.runCeilingTest(targetMB: 1536)
            DispatchQueue.main.async {
                self.apply(result: res)
                self.isRunning = false
            }
        }
    }
    
    private func releaseMemory() {
        StrataRAMDonorEngine.shared.releaseAll()
        refreshStats()
        status = "Released"
        resultLog += "\nAll allocations released.\n"
        pooled = "0 MB"
        donors = "0"
    }
    
    private func apply(result: StrataRAMDonorEngine.Result) {
        physicalRAM = mb(result.physicalRAM)
        osAvailable = mb(StrataRAMDonorEngine.shared.osAvailable())
        physFootprint = mb(result.physFootprint)
        pooled = mb(result.pooledTouched)
        donors = "\(result.liveDonors)"
        status = "Diagnostic ended; memory released"
        resultLog = result.log
    }
    
    private func shareReport() {
        let av = UIActivityViewController(activityItems: [resultLog], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        if let pop = av.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        presenter.present(av, animated: true)
    }
}
