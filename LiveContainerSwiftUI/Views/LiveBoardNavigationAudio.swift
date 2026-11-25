import Foundation
import AudioToolbox
import UIKit
import Darwin

/// Original short navigation cue; system sound playback does not replace a guest audio session.
@MainActor final class LiveBoardNavigationAudio: ObservableObject {
    enum Cue: String { case selection, confirm, back }
    private var sounds: [Cue: SystemSoundID] = [:]
    private var urls: [URL] = []
    private var lastPlay = Date.distantPast
    func play() { play(.selection, preview: false) }
    func play(_ cue: Cue, preview: Bool = false) {
        let defaults = LCUtils.appGroupUserDefault
        let enabled = defaults.object(forKey: "LiveBoardConsoleSounds") as? Bool
            ?? defaults.object(forKey: "ZNBetaNavigationAudio") as? Bool ?? true
        guard enabled, !defaults.bool(forKey: "ZNBetaLowMemory") else { return }
        guard ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical else { return }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard Date().timeIntervalSince(lastPlay) > (preview ? 0.02 : 0.07) else { return }
        lastPlay = Date()
        guard let id = sounds[cue] else {
            let style = defaults.string(forKey: "ZNBetaSoundStyle") ?? "classic"
            let base: Double = style == "soft" ? 440 : (style == "arcade" ? 1040 : 740)
            let frequency = base * (cue == .confirm ? 1.25 : cue == .back ? 0.72 : 1)
            let rate = 22050, count = cue == .selection ? 1102 : 1654
            var pcm = Data()
            for index in 0..<count {
                let t = Double(index) / Double(rate)
                let envelope = sin(Double.pi * Double(index) / Double(count)) * exp(-t * (cue == .confirm ? 34 : 54))
                var value = Int16(sin(t * 2 * Double.pi * frequency) * envelope * 2600).littleEndian
                withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
            }
            var data = Data("RIFF".utf8)
            func u32(_ value: UInt32) { var x = value.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
            func u16(_ value: UInt16) { var x = value.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
            u32(UInt32(36 + pcm.count)); data.append(Data("WAVEfmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16); data.append(Data("data".utf8)); u32(UInt32(pcm.count)); data.append(pcm)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Strata-Navigation-\(cue.rawValue).wav")
            do { try data.write(to: url, options: .atomic) } catch { return }
            var created: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url as CFURL, &created) == kAudioServicesNoError else { try? FileManager.default.removeItem(at: url); return }
            sounds[cue] = created; urls.append(url)
            AudioServicesPlaySystemSound(created)
            return
        }
        AudioServicesPlaySystemSound(id)
    }
    func stop() {
        sounds.values.forEach { AudioServicesDisposeSystemSoundID($0) }
        sounds.removeAll()
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
        urls.removeAll()
    }
    deinit { for id in sounds.values { AudioServicesDisposeSystemSoundID(id) }; for url in urls { try? FileManager.default.removeItem(at: url) } }
}
