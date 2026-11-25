import SwiftUI
import UIKit

// MARK: - Pure Swift RAM Donor (no ObjC / pbxproj required)

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
    
    func runCeilingTest(targetMB: Int) -> Result {
        var r = Result()
        r.physicalRAM = physicalRAM()
        r.osAvailable = osAvailable()
        var log = "=== Ceiling Test ===\nTarget: \(targetMB) MB\n"
        
        let pageSize = Int(getpagesize())
        let chunkSize = 64 * 1024 * 1024
        let targetBytes = targetMB * 1024 * 1024
        var allocated = 0
        var mismatches: UInt64 = 0
        
        while allocated < targetBytes {
            let thisChunk = min(chunkSize, targetBytes - allocated)
            guard let ptr = malloc(thisChunk) else {
                log += "malloc failed at \(allocated / (1024*1024)) MB\n"
                break
            }
            
            var i = 0
            while i < thisChunk {
                ptr.storeBytes(of: UInt8(i & 0xFF), toByteOffset: i, as: UInt8.self)
                i += pageSize
            }
            
            i = 0
            while i < thisChunk {
                if ptr.load(fromByteOffset: i, as: UInt8.self) != UInt8(i & 0xFF) {
                    mismatches += 1
                }
                i += pageSize
            }
            
            lock.lock()
            allocations.append(ptr)
            allocationSizes.append(thisChunk)
            lock.unlock()
            
            allocated += thisChunk
            log += "Allocated + touched: \(allocated / (1024*1024)) MB | Footprint: \(String(format: "%.1f", Double(physFootprint()) / 1024.0 / 1024.0)) MB\n"
        }
        
        r.physFootprint = physFootprint()
        r.pooledTouched = UInt64(allocated)
        r.pagesVerified = UInt64(allocated / pageSize)
        r.mismatches = mismatches
        r.exceedsLimit = r.physFootprint > r.osAvailable
        r.log = log
        return r
    }
    
    func runDonorTest(targetMB: Int, donorCount: Int) -> Result {
        var r = Result()
        r.physicalRAM = physicalRAM()
        r.osAvailable = osAvailable()
        var log = "=== Donor Test ===\nTarget: \(targetMB) MB | Donors: \(donorCount)\n"
        
        let pageSize = Int(getpagesize())
        let perDonor = (targetMB * 1024 * 1024) / max(donorCount, 1)
        var totalAllocated = 0
        var mismatches: UInt64 = 0
        var successDonors = 0
        
        for d in 0..<donorCount {
            guard let ptr = malloc(perDonor) else {
                log += "Donor \(d) failed to allocate\n"
                continue
            }
            
            var i = 0
            while i < perDonor {
                ptr.storeBytes(of: UInt8((d + i) & 0xFF), toByteOffset: i, as: UInt8.self)
                i += pageSize
            }
            
            i = 0
            while i < perDonor {
                if ptr.load(fromByteOffset: i, as: UInt8.self) != UInt8((d + i) & 0xFF) {
                    mismatches += 1
                }
                i += pageSize
            }
            
            lock.lock()
            allocations.append(ptr)
            allocationSizes.append(perDonor)
            lock.unlock()
            
            totalAllocated += perDonor
            successDonors += 1
            log += "Donor \(d): +\(perDonor/(1024*1024)) MB | Total pooled: \(totalAllocated/(1024*1024)) MB\n"
        }
        
        r.physFootprint = physFootprint()
        r.pooledTouched = UInt64(totalAllocated)
        r.liveDonors = successDonors
        r.pagesVerified = UInt64(totalAllocated / pageSize)
        r.mismatches = mismatches
        r.exceedsLimit = (r.pooledTouched > r.osAvailable) || (r.physFootprint > UInt64(Double(r.osAvailable) * 0.9))
        log += "\nResult: \(r.exceedsLimit ? "EXCEEDS LIMIT, bypass works" : "Within normal limit")\n"
        r.log = log
        return r
    }
    
    func releaseAll() {
        lock.lock()
        for (i, ptr) in allocations.enumerated() {
            free(ptr)
            _ = allocationSizes[i]
        }
        allocations.removeAll()
        allocationSizes.removeAll()
        lock.unlock()
        malloc_zone_pressure_relief(nil, 0)
    }
}

// MARK: - UI

struct StrataRAMDonorView: View {
    @State private var resultLog: String = "Ready."
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
                        row("OS Available (limit)", osAvailable)
                        row("Phys Footprint", physFootprint)
                        row("Pooled + Touched", pooled)
                        row("Live Donors", donors)
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
                        Label("Run Donor Test (pool + verify)", systemImage: "memorychip")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                    
                    Button {
                        runCeilingTest()
                    } label: {
                        Label("Ceiling Test (malloc + touch)", systemImage: "arrow.up.to.line")
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
        resultLog = "Starting donor test...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let res = StrataRAMDonorEngine.shared.runDonorTest(targetMB: 10240, donorCount: 8)
            DispatchQueue.main.async {
                self.apply(result: res)
                self.isRunning = false
            }
        }
    }
    
    private func runCeilingTest() {
        isRunning = true
        status = "Running Ceiling Test..."
        resultLog = "Starting ceiling test...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let res = StrataRAMDonorEngine.shared.runCeilingTest(targetMB: 6144)
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
        osAvailable = mb(result.osAvailable)
        physFootprint = mb(result.physFootprint)
        pooled = mb(result.pooledTouched)
        donors = "\(result.liveDonors)"
        status = result.exceedsLimit ? "EXCEEDS LIMIT, bypass works" : "Within limit"
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
