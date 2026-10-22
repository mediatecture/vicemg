import Foundation
import AVFoundation

/// Plays a synthesized two-tone emergency siren. The WAV is generated in memory,
/// so there's no audio asset to bundle.
final class AlarmPlayer {
    static let shared = AlarmPlayer()

    private var player: AVAudioPlayer?

    private init() {}

    func play() {
        player?.stop()
        guard let player = try? AVAudioPlayer(data: Self.sirenWAV) else {
            print("Alarm: couldn't create audio player")
            return
        }
        player.volume = 1.0
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // MARK: - Siren synthesis

    private static let sampleRate = 44_100
    private static let duration = 5.0          // seconds
    private static let toneLength = 0.5        // seconds per tone before switching
    private static let highTone = 960.0        // Hz
    private static let lowTone = 770.0         // Hz

    private static let sirenWAV: Data = {
        let frameCount = Int(Double(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(frameCount)

        var phase = 0.0
        for frame in 0..<frameCount {
            let t = Double(frame) / Double(sampleRate)
            let freq = Int(t / toneLength) % 2 == 0 ? highTone : lowTone
            phase += 2 * Double.pi * freq / Double(sampleRate)

            // Fundamental plus a third harmonic gives a harsher, more alarm-like timbre.
            var value = sin(phase) + 0.3 * sin(3 * phase)

            // Short fade in/out on the whole clip to avoid clicks.
            let fade = min(1.0, t / 0.02, (duration - t) / 0.05)
            value *= 0.7 * fade

            samples.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
        }
        return wavData(samples: samples, sampleRate: sampleRate)
    }()

    private static func wavData(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize = samples.count * MemoryLayout<Int16>.size
        var data = Data()

        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))                       // PCM chunk size
        append(UInt16(1))                        // PCM format
        append(UInt16(1))                        // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))           // byte rate
        append(UInt16(2))                        // block align
        append(UInt16(16))                       // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize))
        for sample in samples { append(sample) }
        return data
    }
}
