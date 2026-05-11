import AVFoundation
import Foundation

final class SoundPlayer {
    private var player: AVAudioPlayer?

    func playBoundarySound(enabled: Bool) {
        guard enabled, let data = Self.makePakuSoundData() else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = 0.28
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            self.player = nil
        }
    }

    private static func makePakuSoundData() -> Data? {
        let sampleRate = 44_100
        let duration = 0.18
        let sampleCount = Int(Double(sampleRate) * duration)
        var pcm = Data()

        for sampleIndex in 0..<sampleCount {
            let progress = Double(sampleIndex) / Double(sampleCount)
            let frequency = 460.0 + 250.0 * sin(progress * .pi)
            let envelope = sin(progress * .pi)
            let value = sin(2.0 * .pi * frequency * Double(sampleIndex) / Double(sampleRate)) * envelope * 0.45
            let intValue = Int16(max(-1, min(1, value)) * Double(Int16.max))
            appendInt16(intValue, to: &pcm)
        }

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        appendUInt32(UInt32(36 + pcm.count), to: &data)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        appendUInt32(16, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(1, to: &data)
        appendUInt32(UInt32(sampleRate), to: &data)
        appendUInt32(UInt32(sampleRate * 2), to: &data)
        appendUInt16(2, to: &data)
        appendUInt16(16, to: &data)
        data.append("data".data(using: .ascii)!)
        appendUInt32(UInt32(pcm.count), to: &data)
        data.append(pcm)
        return data
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static func appendInt16(_ value: Int16, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
