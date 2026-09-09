#!/usr/bin/env swift
// Run from any directory: swift scripts/prepare_audio.swift
// Uses only macOS frameworks. Decodes local files without playing audio or fetching data.
import Foundation
import AVFoundation
import CryptoKit

struct Line: Codable {
    let id: String
    let text: String
    var audioAsset: String
}

struct UpstreamClip: Decodable {
    let file: String
    let source: String
    let sha256: String
}

struct Levels: Codable {
    let rmsDBFS: Double
    let samplePeakDBFS: Double
    let durationSeconds: Double
    let sampleRate: Double
    let channels: Int
    let frames: Int
    let fullScaleSamples: Int
}

struct Derivation: Codable {
    let id: String
    let originalFile: String
    let originalSHA256: String
    let sourceURL: String
    let sourceCommit: String?
    let outputFile: String
    let outputSHA256: String
    let gainDB: Double
    let peakLimited: Bool
    let input: Levels
    let output: Levels
}

struct Normalization: Encodable {
    let schemaVersion = 1
    let method = "One constant gain per clip, measured over all decoded samples and channels. No trimming, compression, denoising, or playback."
    let script = "scripts/prepare_audio.swift"
    let outputFormat = "16-bit signed little-endian PCM WAV; original sample rate and channel count"
    let targetRMSDBFS: Double
    let samplePeakCeilingDBFS: Double
    let minimumSamplePeakHeadroomDB: Double
    let validation = "Outputs were decoded again and checked for preserved frame count, duration, rate and channels; RMS within 0.02 dB of expected gain; sample peaks at or below -3 dBFS; no full-scale samples. This is objective level balancing, not a listening test or perceptual LUFS normalization."
    let sources: [String: String]
    let clips: [Derivation]
}

enum PreparationError: Error {
    case invalid(String)
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw PreparationError.invalid(message) }
}

func sha256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}

func decode(_ url: URL) throws -> AVAudioPCMBuffer {
    let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
    try require(file.length > 0 && file.length <= Int64(UInt32.max), "Invalid length: \(url.path)")
    guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
        throw PreparationError.invalid("Cannot allocate decoded buffer: \(url.path)")
    }
    try file.read(into: buffer)
    return buffer
}

func levels(_ buffer: AVAudioPCMBuffer) throws -> Levels {
    guard let channels = buffer.floatChannelData else { throw PreparationError.invalid("Expected Float32 PCM") }
    let count = Int(buffer.frameLength) * Int(buffer.format.channelCount)
    try require(count > 0, "Empty decoded audio")
    var squares = 0.0
    var peak = 0.0
    var fullScale = 0
    for channel in 0..<Int(buffer.format.channelCount) {
        for frame in 0..<Int(buffer.frameLength) {
            let sample = abs(Double(channels[channel][frame]))
            try require(sample.isFinite, "Non-finite decoded sample")
            squares += sample * sample
            peak = max(peak, sample)
            if sample >= 1 { fullScale += 1 }
        }
    }
    try require(squares > 0 && peak > 0, "Silent source clip")
    return Levels(rmsDBFS: 20 * log10(sqrt(squares / Double(count))),
                  samplePeakDBFS: 20 * log10(peak),
                  durationSeconds: Double(buffer.frameLength) / buffer.format.sampleRate,
                  sampleRate: buffer.format.sampleRate, channels: Int(buffer.format.channelCount),
                  frames: Int(buffer.frameLength), fullScaleSamples: fullScale)
}

func writePCM(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: buffer.format.sampleRate,
        AVNumberOfChannelsKey: buffer.format.channelCount,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]
    // Closing the writer before validation finalizes the WAV header.
    let output = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    try output.write(from: buffer)
}

func encode<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(10)
    try data.write(to: url, options: .atomic)
}

let targetRMS = -20.0
// 0.01 dB extra margin keeps 16-bit rounding safely below the 3 dB headroom requirement.
let peakCeiling = -3.01

// The same offline preparation policy applies to dialogue and sound effects.
func normalize(_ provenance: UpstreamClip, id: String, root: URL,
               outputFile: String, sourceCommit: String? = nil) throws -> Derivation {
    let inputURL = root.appendingPathComponent(provenance.file)
    try require(try sha256(inputURL) == provenance.sha256, "Original checksum mismatch: \(provenance.file)")
    let buffer = try decode(inputURL)
    let before = try levels(buffer)
    let desiredGain = targetRMS - before.rmsDBFS
    let gain = min(desiredGain, peakCeiling - before.samplePeakDBFS)
    let multiplier = Float(pow(10, gain / 20))
    for channel in 0..<Int(buffer.format.channelCount) {
        for frame in 0..<Int(buffer.frameLength) { buffer.floatChannelData![channel][frame] *= multiplier }
    }
    let outputURL = root.appendingPathComponent(outputFile)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try writePCM(buffer, to: outputURL)
    let after = try levels(decode(outputURL))
    try require(after.frames == before.frames && after.sampleRate == before.sampleRate && after.channels == before.channels, "Output timing/format changed: \(id)")
    try require(abs(after.rmsDBFS - (before.rmsDBFS + gain)) < 0.02, "Output RMS validation failed: \(id)")
    try require(after.samplePeakDBFS <= -3 && after.fullScaleSamples == 0, "Output peak validation failed: \(id)")
    print(String(format: "%@  RMS %.2f -> %.2f dBFS, peak %.2f dBFS, gain %+.2f dB%@", id, before.rmsDBFS, after.rmsDBFS, after.samplePeakDBFS, gain, gain < desiredGain ? " (peak-capped)" : ""))
    return Derivation(id: id, originalFile: provenance.file, originalSHA256: provenance.sha256,
                      sourceURL: provenance.source, sourceCommit: sourceCommit,
                      outputFile: outputFile, outputSHA256: try sha256(outputURL),
                      gainDB: gain, peakLimited: gain < desiredGain, input: before, output: after)
}

do {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let pack = root.appendingPathComponent("assets/sounds/rick")
    let originals = try JSONDecoder().decode([UpstreamClip].self, from: Data(contentsOf: root.appendingPathComponent("research/rick-audio-provenance.json")))
    let originalByName = Dictionary(uniqueKeysWithValues: originals.map { (URL(fileURLWithPath: $0.file).lastPathComponent, $0) })
    var lines = try JSONDecoder().decode([Line].self, from: Data(contentsOf: pack.appendingPathComponent("lines.json")))
    let signatureIDs = ["pickle_rick", "i_turned_myself_into_a_pickle", "hey_morty"]
    let approvedIDs = Set(originals.map { clip -> String in
        let filename = URL(fileURLWithPath: clip.file).lastPathComponent
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        return signatureIDs.contains(stem) ? stem : filename
    })
    try require(lines.count == 17 && Set(lines.map(\.id)) == approvedIDs, "Expected exactly the 17 approved stable line IDs")
    let signatureLines = try signatureIDs.map { id -> Line in
        guard let line = lines.first(where: { $0.id == id }) else { throw PreparationError.invalid("Missing signature line: \(id)") }
        return line
    }
    lines = signatureLines + lines.filter { !signatureIDs.contains($0.id) }

    let sources = [
        "PeonPing/og-packs@v1.0.0": "ec8630d43ae2cdb2af2617aa69a3df7737ec1c6d",
        "Mr3zee/peonping-rick-and-morty-clean@v1.0.0": "125e30394baa24b70958e69ac7d87a6f5f401428"
    ]
    var derivations: [Derivation] = []
    for index in lines.indices {
        let id = lines[index].id
        let originalName = id.hasSuffix(".mp3") ? id : id + ".mp3"
        guard let provenance = originalByName[originalName] else { throw PreparationError.invalid("Missing provenance for \(id)") }
        let outputName = URL(fileURLWithPath: originalName).deletingPathExtension().lastPathComponent + ".wav"
        let relativeOutput = "normalized/" + outputName
        lines[index].audioAsset = "rick/" + relativeOutput
        let upstream = provenance.source.contains("/PeonPing/") ? "PeonPing/og-packs@v1.0.0" : "Mr3zee/peonping-rick-and-morty-clean@v1.0.0"
        derivations.append(try normalize(provenance, id: id, root: root,
                                         outputFile: "assets/sounds/rick/" + relativeOutput,
                                         sourceCommit: sources[upstream]!))
    }
    let normalization = Normalization(targetRMSDBFS: targetRMS, samplePeakCeilingDBFS: peakCeiling,
                                      minimumSamplePeakHeadroomDB: 3, sources: sources, clips: derivations)
    try encode(normalization, to: pack.appendingPathComponent("normalization.json"))
    try encode(lines, to: pack.appendingPathComponent("lines.json"))

    let peonPack = root.appendingPathComponent("assets/sounds/peon")
    let peonLines = try JSONDecoder().decode([Line].self, from: Data(contentsOf: peonPack.appendingPathComponent("lines.json")))
    let peonOriginals = try JSONDecoder().decode([UpstreamClip].self, from: Data(contentsOf: root.appendingPathComponent("research/peon-audio-provenance.json")))
    let peonByName = Dictionary(uniqueKeysWithValues: peonOriginals.map { (URL(fileURLWithPath:$0.file).lastPathComponent,$0) })
    let peonCommit = "5d1245fe0188c8da775ca8875c32ee7bf8d92c57"
    try require(peonLines.count == 17 && Set(peonLines.map(\.id)) == Set(peonByName.keys), "Expected the complete 17-clip Peon Ping peon pack")
    let peonDerivations = try peonLines.map { line in
        try require(line.audioAsset == "peon/normalized/" + line.id, "Unexpected peon output path")
        return try normalize(peonByName[line.id]!, id:line.id, root:root,
                             outputFile:"assets/sounds/" + line.audioAsset, sourceCommit:peonCommit)
    }
    let peonNormalization = Normalization(targetRMSDBFS:targetRMS, samplePeakCeilingDBFS:peakCeiling,
                                          minimumSamplePeakHeadroomDB:3,
                                          sources:["PeonPing/og-packs (peon 1.1.0)":peonCommit], clips:peonDerivations)
    try encode(peonNormalization, to:peonPack.appendingPathComponent("normalization.json"))

    struct Effect: Decodable { let id: String; let audioAsset: String }
    let effectsPack = root.appendingPathComponent("assets/sounds/effects")
    let effects = try JSONDecoder().decode([Effect].self, from: Data(contentsOf: effectsPack.appendingPathComponent("effects.json")))
    let effectSources = try JSONDecoder().decode([UpstreamClip].self, from: Data(contentsOf: root.appendingPathComponent("research/portal-audio-provenance.json")))
    try require(effects.count == 1 && effects[0].id == "portal-open" && effectSources.count == 1, "Expected the portal opening effect and its pinned source")
    let portal = try normalize(effectSources[0], id: effects[0].id, root: root,
                               outputFile: "assets/sounds/" + effects[0].audioAsset)
    let effectNormalization = Normalization(targetRMSDBFS: targetRMS, samplePeakCeilingDBFS: peakCeiling,
                                            minimumSamplePeakHeadroomDB: 3,
                                            sources: ["SoundboardGuy": "https://soundboardguy.com/sounds/rick-and-morty-portal-sound/"],
                                            clips: [portal])
    try encode(effectNormalization, to: effectsPack.appendingPathComponent("normalization.json"))

    // openpeon.json stays the unmodified upstream 14-clip manifest, retained for provenance.
    // lines.json is the actual 17-clip playback inventory; normalization.json records its derivation.
    print("Prepared and validated \(lines.count + peonLines.count) voices and \(effects.count) effect. Original recordings were unchanged.")
} catch {
    FileHandle.standardError.write(Data("Audio preparation failed: \(error)\n".utf8))
    exit(1)
}
