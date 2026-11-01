// Copyright © 2026 Anton Novoselov. All rights reserved.

@preconcurrency import FluidAudio
import Foundation
import TranscriptionCore
import ZIPFoundation
import WhisperKit

/// Stateless download helpers that wrap WhisperKit + FluidAudio. The app's
/// `ModelDownloadManager` calls these instead of importing the SDKs directly,
/// keeping `WhisperKit` and `FluidAudio` confined to this module.
///
/// Each download is a one-shot async function. Callers own all UI state
/// (`@Observable` progress dicts, status enums, cancellation tasks). The
/// helpers just translate SDK progress into a uniform `Double` (0.0...1.0).
public enum LocalModelDownloader {
    /// Receives normalized progress between 0.0 and 1.0.
    public typealias ProgressHandler = @Sendable (Double) -> Void

    // MARK: - Download source

    /// Where WhisperKit pulls model files from.
    ///
    /// Hugging Face is frequently unreachable or extremely slow from mainland
    /// China, which made the 632 MB Whisper models effectively undownloadable.
    /// `hf-mirror.com` is a reverse proxy for the same repositories, so the
    /// file layout is identical and no repackaging is needed.
    ///
    /// Parakeet (FluidAudio) does not expose an endpoint override, so it always
    /// uses Hugging Face regardless of this setting.
    public enum ModelHost: String, Sendable, CaseIterable {
        case huggingFace
        case mirror
        /// Project-hosted CDN. Ships as the default because Hugging Face is
        /// unreachable for most users in mainland China and the mirror is slow.
        case qiniu
        /// A self-hosted zip of one model variant, e.g. on a CDN.
        case custom

        /// Uses any of the zip-based ("custom" archive) download paths.
        public var usesZipArchive: Bool {
            self == .qiniu || self == .custom
        }

        /// Host passed to `WhisperKit.download(endpoint:)`. Only meaningful for
        /// the two repository-backed options.
        public var whisperKitEndpoint: String {
            switch self {
            case .huggingFace: "https://huggingface.co"
            case .mirror: "https://hf-mirror.com"
            case .qiniu, .custom: "https://huggingface.co"
            }
        }

        public var displayName: String {
            switch self {
            case .huggingFace: "Hugging Face"
            case .mirror: "HF Mirror"
            case .qiniu: "Qiniu CDN"
            case .custom: "Custom URL"
            }
        }
    }

    /// Downloads a zipped model variant from a self-hosted URL and unpacks it
    /// into the WhisperKit cache layout.
    ///
    /// The archive must contain a single top-level folder named after the model
    /// variant (e.g. `openai_whisper-large-v3-v20240930_turbo_632MB/`).
    public static func downloadZippedWhisperKit(
        modelName: String,
        from remoteURL: URL,
        onPhase: @escaping WhisperKitPhaseHandler
    ) async throws {
        let destination = WhisperKitModelPath.directory(forModelName: modelName)
        if FileManager.default.fileExists(atPath: destination.path) {
            onPhase(.downloading(fractionCompleted: 1.0))
            return
        }

        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        onPhase(.downloading(fractionCompleted: 0))

        let (tempFile, response) = try await URLSession.shared.download(from: remoteURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LocalModelDownloadError.badStatus(http.statusCode)
        }
        onPhase(.downloading(fractionCompleted: 0.9))

        // `download(from:)` hands back a temp file that disappears when this
        // scope ends, so move it somewhere stable before unzipping.
        let archive = parent.appendingPathComponent("\(modelName).zip")
        try? FileManager.default.removeItem(at: archive)
        try FileManager.default.moveItem(at: tempFile, to: archive)
        defer { try? FileManager.default.removeItem(at: archive) }

        let unpackRoot = parent.appendingPathComponent(".unzip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unpackRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: unpackRoot) }

        try unzip(archive, into: unpackRoot)

        // Accept both `root/<modelName>/` and a flat `root/*`.
        let nested = unpackRoot.appendingPathComponent(modelName, isDirectory: true)
        let source = FileManager.default.fileExists(atPath: nested.path) ? nested : unpackRoot
        try moveContents(of: source, into: destination)

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw LocalModelDownloadError.emptyArchive
        }
        onPhase(.downloading(fractionCompleted: 1.0))
    }

    /// Unpacks an archive with ZIPFoundation (pure Swift - iOS ships no
    /// `unzip` binary, and `libarchive` headers are not in the SDK).
    private static func unzip(_ archive: URL, into directory: URL) throws {
        try FileManager.default.unzipItem(at: archive, to: directory)
    }

    private static func moveContents(of source: URL, into destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            try? fm.removeItem(at: target)
            try fm.moveItem(at: item, to: target)
        }
    }

    // MARK: - Parakeet

    /// Downloads (if not cached) and validates the Parakeet ASR model plus the
    /// VAD model for the given version. Progress is unified across both
    /// phases: ASR occupies 0.0...0.85, VAD occupies 0.85...1.0.
    public static func downloadParakeet(
        version: ParakeetModelVersion,
        onProgress: @escaping ProgressHandler
    ) async throws {
        let asrVersion = asrModelVersion(for: version)

        _ = try await AsrModels.downloadAndLoad(
            version: asrVersion,
            progressHandler: { progress in
                onProgress(progress.fractionCompleted * 0.85)
            }
        )

        try Task.checkCancellation()

        _ = try await VadManager(
            progressHandler: { progress in
                onProgress(0.85 + progress.fractionCompleted * 0.15)
            }
        )
    }

    // MARK: - WhisperKit

    /// Phases the WhisperKit setup pipeline emits. Callers use them to drive
    /// their own progress UI (e.g. animate between fixed checkpoints during
    /// the long prewarm + load steps).
    public enum WhisperKitPhase: Sendable {
        /// File download in progress. `fractionCompleted` is 0.0...1.0 across
        /// the network download only.
        case downloading(fractionCompleted: Double)
        /// Files are present on disk (either freshly downloaded or already
        /// cached). Prewarm is about to start.
        case prewarmStart
        /// Prewarm finished; load is about to start.
        case loadStart
        /// Load finished; the model has been unloaded again to free memory.
        case finished
    }

    public typealias WhisperKitPhaseHandler = @Sendable (WhisperKitPhase) -> Void

    /// Downloads the WhisperKit model (if missing), prewarms it, loads it,
    /// then unloads it again. This is the first-run setup flow - subsequent
    /// transcriptions reload from the prewarmed Core ML cache and are fast.
    ///
    /// Honors `Task.checkCancellation()` at each phase boundary.
    public static func downloadAndPrepareWhisperKit(
        modelName: String,
        host: ModelHost = .huggingFace,
        customArchiveURL: URL? = nil,
        onPhase: @escaping WhisperKitPhaseHandler
    ) async throws {
        let config = WhisperKitConfig(
            verbose: false,
            logLevel: .info,
            prewarm: false,
            load: false,
            download: false
        )

        let whisperKit = try await WhisperKit(config)
        try Task.checkCancellation()

        let modelFolder = WhisperKitModelPath.directory(forModelName: modelName)

        if FileManager.default.fileExists(atPath: modelFolder.path) {
            whisperKit.modelFolder = modelFolder
            onPhase(.downloading(fractionCompleted: 1.0))
        } else if host.usesZipArchive, let customArchiveURL {
            try await downloadZippedWhisperKit(modelName: modelName, from: customArchiveURL, onPhase: onPhase)
            whisperKit.modelFolder = modelFolder
        } else {
            let downloadedFolder = try await WhisperKit.download(
                variant: modelName,
                from: "argmaxinc/whisperkit-coreml",
                endpoint: host.whisperKitEndpoint,
                progressCallback: { @Sendable progress in
                    onPhase(.downloading(fractionCompleted: progress.fractionCompleted))
                }
            )
            whisperKit.modelFolder = downloadedFolder
        }

        try Task.checkCancellation()
        onPhase(.prewarmStart)
        try await whisperKit.prewarmModels()
        try Task.checkCancellation()

        onPhase(.loadStart)
        try await whisperKit.loadModels()
        try Task.checkCancellation()

        await whisperKit.unloadModels()
        onPhase(.finished)
    }
}


/// Failures specific to self-hosted model archives.
public enum LocalModelDownloadError: LocalizedError {
    case badStatus(Int)
    case unzipFailed(String)
    case emptyArchive

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code): "Server returned HTTP \(code)."
        case .unzipFailed(let detail): "Could not unzip the model archive: \(detail)"
        case .emptyArchive: "The model archive did not contain the expected folder."
        }
    }
}
