//
//  SmartSearchSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.12
//

import SwiftUI
import SwiftData
import DesignSystem
import os

/// Settings screen for RAG Smart Search configuration.
///
/// Smart Search needs an on-device embedding model (~90 MB). Nothing is
/// downloaded implicitly: the model is fetched only when the user taps
/// Download, mirroring how local transcription models work.
struct SmartSearchSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SmartSearchFeature.isEnabledKey) private var isSmartSearchEnabled = false

    @State private var isReindexing = false
    @State private var isDownloading = false
    @State private var downloadFailed = false
    @State private var service = RAGIndexingService.shared
    @AppStorage(SmartSearchFeature.relevanceThresholdKey)
    private var relevanceThreshold = SmartSearchFeature.defaultRelevanceThreshold

    private let logger = Logger(category: .ragIndexing)

    private var isModelReady: Bool { service.isEmbeddingModelReady }
    private var isBusy: Bool { isDownloading || isReindexing || service.isIndexing }

    /// Hex shows the model card once the user can actually use it.
    private var showsIndexStats: Bool { isModelReady && isSmartSearchEnabled }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                modelCard
                if isModelReady {
                    relevanceCard
                    indexingCard
                }
                aboutCard
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Smart Search")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isSmartSearchEnabled) { _, isEnabled in
            logger.logInfo("Smart Search settings toggled enabled=\(isEnabled) indexedNotes=\(service.indexedTranscriptionCount)")
            guard isEnabled else {
                isReindexing = true
                Task {
                    await service.clearAll()
                    isReindexing = false
                }
                return
            }
            // Enabling without the model present: don't start indexing silently.
            guard isModelReady else { return }
            isReindexing = true
            Task {
                await service.indexAllIfNeeded(modelContext: modelContext)
                isReindexing = false
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 26))
                    .foregroundStyle(.blue)
                    .frame(width: 46, height: 46)
                    .background(.blue.opacity(0.14), in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Semantic Search")
                        .font(.headline)
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                statusBadge
            }

            Text("Find notes by meaning, not just keywords. Ask “what did I say about pricing?” and VivaDicta finds it — even without those exact words.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modelCardBackground()
    }

    private var statusLine: String {
        if isDownloading { return String(localized: "Downloading model…") }
        if !isModelReady { return String(localized: "Model not downloaded") }
        if service.isIndexing || isReindexing { return String(localized: "Indexing your notes…") }
        if isSmartSearchEnabled { return String(localized: "Ready · \(service.indexedTranscriptionCount) notes indexed") }
        return String(localized: "Model ready · turned off")
    }

    @ViewBuilder
    private var statusBadge: some View {
        Group {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if isSmartSearchEnabled, isModelReady {
                Label("On", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text(isModelReady ? "Off" : "Not set up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: .capsule)
    }

    // MARK: - Model

    @ViewBuilder
    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Model")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if isModelReady {
                Toggle(isOn: $isSmartSearchEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable Smart Search")
                            .font(.body)
                        Text("Search your notes by meaning in the app's search bar and chats.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)
                .onChange(of: isSmartSearchEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }

                Divider()

                HStack {
                    Text("Model")
                    Spacer()
                    Text(verbatim: "BAAI/bge-small-zh")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                if showsIndexStats {
                    HStack {
                        Text("Indexed Notes")
                        Spacer()
                        if service.isIndexing || isReindexing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("\(service.indexedTranscriptionCount)")
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.subheadline)
                }
            } else {
                Text("Download the on-device model to search your notes by meaning. Supports Chinese and English.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    downloadModel()
                } label: {
                    HStack(spacing: 8) {
                        if isDownloading {
                            ProgressView().controlSize(.small).tint(.white)
                            Text("Downloading…")
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Model (\(RAGIndexingService.embeddingModelApproxMB) MB)")
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                }
                .prominentButton(color: .green)
                .disabled(isDownloading)

                if isDownloading {
                    Text("Keep the app open and stay connected. This can take a few minutes.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if downloadFailed {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Download failed.")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Retry") { downloadModel() }
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modelCardBackground()
    }

    // MARK: - Relevance

    /// Slider letting the user loosen/tighten how close a note must be to the
    /// query before it shows up. Lower = more results (some noise), higher =
    /// fewer but more precise. Applied on the next search; no re-index needed.
    private var relevanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Match Strictness")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                Text("Minimum relevance")
                Spacer()
                Text(relevanceThreshold, format: .number.precision(.fractionLength(2)))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .font(.subheadline)

            Slider(
                value: $relevanceThreshold,
                in: SmartSearchFeature.relevanceThresholdRange,
                step: 0.01
            ) {
                Text("Minimum relevance")
            } minimumValueLabel: {
                // Loose end: many results, wider spread.
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                // Strict end: only tightly matching results.
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tint(.green)
            .onChange(of: relevanceThreshold) { _, _ in
                HapticManager.selectionChanged()
            }

            HStack {
                Text(strictnessHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if relevanceThreshold != SmartSearchFeature.defaultRelevanceThreshold {
                    Button("Reset") {
                        relevanceThreshold = SmartSearchFeature.defaultRelevanceThreshold
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modelCardBackground()
    }

    /// Plain-language description of what the current value does.
    private var strictnessHint: String {
        switch relevanceThreshold {
        case ..<0.45: String(localized: "More results — may include loosely related notes.")
        case ..<0.65: String(localized: "Balanced — recommended for most notes.")
        default: String(localized: "Fewer, closer results — only strong matches.")
        }
    }

    // MARK: - Indexing

    private var indexingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Index")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Button {
                logger.logInfo("Smart Search settings requested manual reindex indexedNotes=\(service.indexedTranscriptionCount)")
                isReindexing = true
                Task {
                    await service.reindexAll(modelContext: modelContext)
                    logger.logInfo("Smart Search settings manual reindex finished indexedNotes=\(service.indexedTranscriptionCount)")
                    isReindexing = false
                }
            } label: {
                HStack {
                    Label("Re-index All Notes", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if isReindexing {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(isBusy)

            Text("Rebuilds the search index from scratch. Use this if search results seem incorrect.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modelCardBackground()
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Label {
                Text("All processing happens on this device. Your notes are never uploaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
            }

            Text("Smart Search powers semantic search results in the search bar, Smart Chat, and the cross-note search tool. Turning it off stops indexing and hides those surfaces.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modelCardBackground()
    }

    // MARK: - Actions

    private func downloadModel() {
        guard !isDownloading else { return }
        isDownloading = true
        downloadFailed = false
        HapticManager.lightImpact()
        Task {
            do {
                try await service.downloadEmbeddingModelIfNeeded(modelContext: modelContext)
                logger.logInfo("Smart Search model download succeeded")
                HapticManager.success()
            } catch {
                logger.logError("Smart Search model download failed: \(error.localizedDescription)")
                downloadFailed = true
                HapticManager.error()
            }
            isDownloading = false
        }
    }
}
