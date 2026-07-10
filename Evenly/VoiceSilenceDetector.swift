import Foundation

struct VoiceSilenceDetector {
    let silenceDuration: TimeInterval
    let speechThresholdDB: Double
    let silenceThresholdDB: Double

    private(set) var hasDetectedSpeech = false
    private var accumulatedSilence: TimeInterval = 0
    private var hasTriggered = false

    init(
        silenceDuration: TimeInterval = 1.8,
        speechThresholdDB: Double = -35,
        silenceThresholdDB: Double = -42
    ) {
        self.silenceDuration = silenceDuration
        self.speechThresholdDB = speechThresholdDB
        self.silenceThresholdDB = silenceThresholdDB
    }

    mutating func observe(levelDB: Double, duration: TimeInterval) -> Bool {
        guard !hasTriggered, duration > 0 else { return hasTriggered }

        if levelDB >= speechThresholdDB {
            hasDetectedSpeech = true
            accumulatedSilence = 0
            return false
        }

        guard hasDetectedSpeech else { return false }
        if levelDB <= silenceThresholdDB {
            accumulatedSilence += duration
            if accumulatedSilence >= silenceDuration {
                hasTriggered = true
                return true
            }
        } else {
            accumulatedSilence = 0
        }
        return false
    }

    static func rmsDB(pcm16 data: Data) -> Double {
        guard data.count >= 2 else { return -120 }
        var sumSquares = 0.0
        var sampleCount = 0
        var index = data.startIndex
        while index + 1 < data.endIndex {
            let low = UInt16(data[index])
            let high = UInt16(data[index + 1]) << 8
            let sample = Double(Int16(bitPattern: low | high)) / Double(Int16.max)
            sumSquares += sample * sample
            sampleCount += 1
            index += 2
        }
        guard sampleCount > 0 else { return -120 }
        let rms = sqrt(sumSquares / Double(sampleCount))
        return rms > 0 ? 20 * log10(rms) : -120
    }
}
