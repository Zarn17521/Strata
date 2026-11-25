import SwiftUI

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
                    
                    ShareLink(item: resultLog) {
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
        let stats = StrataRAMDonor.shared().currentStats()
        physicalRAM = mb(stats["physicalRAM"] as? UInt64 ?? 0)
        osAvailable = mb(stats["osAvailable"] as? UInt64 ?? 0)
        physFootprint = mb(stats["physFootprint"] as? UInt64 ?? 0)
    }
    
    private func runDonorTest() {
        isRunning = true
        status = "Running Donor Test..."
        resultLog = "Starting donor test...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let res = StrataRAMDonor.shared().runDonorTest(withTargetMB: 10240, donorCount: 8)
            
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
            let res = StrataRAMDonor.shared().runCeilingTest(withTargetMB: 6144)
            
            DispatchQueue.main.async {
                self.apply(result: res)
                self.isRunning = false
            }
        }
    }
    
    private func releaseMemory() {
        StrataRAMDonor.shared().releaseAll()
        refreshStats()
        status = "Released"
        resultLog += "\nAll allocations released.\n"
        pooled = "0 MB"
        donors = "0"
    }
    
    private func apply(result: StrataRAMDonorResult) {
        physicalRAM = mb(result.physicalRAM)
        osAvailable = mb(result.osAvailable)
        physFootprint = mb(result.physFootprint)
        pooled = mb(result.pooledTouched)
        donors = "\(result.liveDonors)"
        status = result.exceedsLimit ? "EXCEEDS LIMIT, bypass works" : "Within limit"
        resultLog = result.log
    }
}
