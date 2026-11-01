//
//  MarkdownExportContent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import Foundation

enum MarkdownExportContent: String, CaseIterable, Identifiable, Sendable {
    case allVariations
    case originalOnly
    case originalAndLastVariation
    case lastVariationOnly

    nonisolated static let `default`: MarkdownExportContent = .allVariations
    nonisolated static let userDefaultsKey = "markdownExportContent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allVariations: String(localized: "Original + All Variations")
        case .originalOnly: String(localized: "Original Only")
        case .originalAndLastVariation: String(localized: "Original + Last Variation")
        case .lastVariationOnly: String(localized: "Last Variation Only")
        }
    }

    nonisolated static var current: MarkdownExportContent {
        guard
            let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
            let value = MarkdownExportContent(rawValue: raw)
        else {
            return .default
        }
        return value
    }
}
