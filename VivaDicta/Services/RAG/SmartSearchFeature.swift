//
//  SmartSearchFeature.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import Foundation

enum SmartSearchFeature {
    nonisolated static let isEnabledKey = "smartSearchFeatureEnabled"

    /// Whether every prerequisite is present: the user toggle is on **and**
    /// the on-device embedding model has been downloaded.
    @MainActor
    static var isReady: Bool {
        isEnabled && RAGIndexingService.shared.isEmbeddingModelReady
    }

    // MARK: - Relevance threshold

    /// UserDefaults key holding the minimum relevance score (0...1) a chunk
    /// must reach to be returned by semantic search.
    nonisolated static let relevanceThresholdKey = "smartSearchRelevanceThreshold"

    /// Shipped default. Tuned for `BAAI/bge-small-zh-v1.5`: unrelated Chinese
    /// sentences sit around 0.46, genuine paraphrases around 0.80.
    nonisolated static let defaultRelevanceThreshold: Double = 0.25

    /// Allowed slider range. Below ~0.3 nearly everything matches; above ~0.8
    /// only near-duplicates do.
    nonisolated static let relevanceThresholdRange: ClosedRange<Double> = 0.20...0.80

    /// Current threshold in `0...1`. Falls back to the shipped default when the
    /// user has never moved the slider.
    ///
    /// `nonisolated` so background RAG work can read it; `UserDefaults` reads
    /// are thread-safe.
    nonisolated static var relevanceThreshold: Double {
        get {
            guard UserDefaults.standard.object(forKey: relevanceThresholdKey) != nil else {
                return defaultRelevanceThreshold
            }
            let stored = UserDefaults.standard.double(forKey: relevanceThresholdKey)
            return relevanceThresholdRange.contains(stored) ? stored : defaultRelevanceThreshold
        }
        set {
            let clamped = min(max(newValue, relevanceThresholdRange.lowerBound), relevanceThresholdRange.upperBound)
            UserDefaults.standard.set(clamped, forKey: relevanceThresholdKey)
        }
    }

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: isEnabledKey) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: isEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isEnabledKey)
        }
    }
}
