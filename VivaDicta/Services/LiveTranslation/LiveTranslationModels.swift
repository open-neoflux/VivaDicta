//
//  LiveTranslationModels.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import Foundation
import AppGroup

enum LiveTranslationLanguage: String, CaseIterable, Identifiable, Sendable {
    // Source list: Soniox real-time STT + translation supported languages.
    // https://soniox.com/docs/stt/concepts/supported-languages
    // The same 60-language list is also covered by tts-rt-v1-preview's
    // multilingual voices, so any of these can be used as source or target.
    case afrikaans = "af"
    case albanian = "sq"
    case arabic = "ar"
    case azerbaijani = "az"
    case basque = "eu"
    case belarusian = "be"
    case bengali = "bn"
    case bosnian = "bs"
    case bulgarian = "bg"
    case catalan = "ca"
    case chinese = "zh"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case english = "en"
    case estonian = "et"
    case finnish = "fi"
    case french = "fr"
    case galician = "gl"
    case german = "de"
    case greek = "el"
    case gujarati = "gu"
    case hebrew = "he"
    case hindi = "hi"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja"
    case kannada = "kn"
    case kazakh = "kk"
    case korean = "ko"
    case latvian = "lv"
    case lithuanian = "lt"
    case macedonian = "mk"
    case malay = "ms"
    case malayalam = "ml"
    case marathi = "mr"
    case norwegian = "no"
    case persian = "fa"
    case polish = "pl"
    case portuguese = "pt"
    case punjabi = "pa"
    case romanian = "ro"
    case russian = "ru"
    case serbian = "sr"
    case slovak = "sk"
    case slovenian = "sl"
    case spanish = "es"
    case swahili = "sw"
    case swedish = "sv"
    case tagalog = "tl"
    case tamil = "ta"
    case telugu = "te"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case urdu = "ur"
    case vietnamese = "vi"
    case welsh = "cy"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .afrikaans: String(localized: "Afrikaans")
        case .albanian: String(localized: "Albanian")
        case .arabic: String(localized: "Arabic")
        case .azerbaijani: String(localized: "Azerbaijani")
        case .basque: String(localized: "Basque")
        case .belarusian: String(localized: "Belarusian")
        case .bengali: String(localized: "Bengali")
        case .bosnian: String(localized: "Bosnian")
        case .bulgarian: String(localized: "Bulgarian")
        case .catalan: String(localized: "Catalan")
        case .chinese: String(localized: "Chinese")
        case .croatian: String(localized: "Croatian")
        case .czech: String(localized: "Czech")
        case .danish: String(localized: "Danish")
        case .dutch: String(localized: "Dutch")
        case .english: String(localized: "English")
        case .estonian: String(localized: "Estonian")
        case .finnish: String(localized: "Finnish")
        case .french: String(localized: "French")
        case .galician: String(localized: "Galician")
        case .german: String(localized: "German")
        case .greek: String(localized: "Greek")
        case .gujarati: String(localized: "Gujarati")
        case .hebrew: String(localized: "Hebrew")
        case .hindi: String(localized: "Hindi")
        case .hungarian: String(localized: "Hungarian")
        case .indonesian: String(localized: "Indonesian")
        case .italian: String(localized: "Italian")
        case .japanese: String(localized: "Japanese")
        case .kannada: String(localized: "Kannada")
        case .kazakh: String(localized: "Kazakh")
        case .korean: String(localized: "Korean")
        case .latvian: String(localized: "Latvian")
        case .lithuanian: String(localized: "Lithuanian")
        case .macedonian: String(localized: "Macedonian")
        case .malay: String(localized: "Malay")
        case .malayalam: String(localized: "Malayalam")
        case .marathi: String(localized: "Marathi")
        case .norwegian: String(localized: "Norwegian")
        case .persian: String(localized: "Persian")
        case .polish: String(localized: "Polish")
        case .portuguese: String(localized: "Portuguese")
        case .punjabi: String(localized: "Punjabi")
        case .romanian: String(localized: "Romanian")
        case .russian: String(localized: "Russian")
        case .serbian: String(localized: "Serbian")
        case .slovak: String(localized: "Slovak")
        case .slovenian: String(localized: "Slovenian")
        case .spanish: String(localized: "Spanish")
        case .swahili: String(localized: "Swahili")
        case .swedish: String(localized: "Swedish")
        case .tagalog: String(localized: "Tagalog")
        case .tamil: String(localized: "Tamil")
        case .telugu: String(localized: "Telugu")
        case .thai: String(localized: "Thai")
        case .turkish: String(localized: "Turkish")
        case .ukrainian: String(localized: "Ukrainian")
        case .urdu: String(localized: "Urdu")
        case .vietnamese: String(localized: "Vietnamese")
        case .welsh: String(localized: "Welsh")
        }
    }

    var displayNameWithFlag: String {
        TranscriptionModelProvider.languageWithFlag(rawValue, name: displayName)
    }

    /// Languages alphabetically sorted by display name. Use this for the
    /// "rest" section of the picker.
    static var alphabetical: [LiveTranslationLanguage] {
        allCases.sorted { $0.displayName < $1.displayName }
    }

    /// User's preferred languages from `Locale.preferredLanguages`, intersected
    /// with what we support, in order of preference. Used to surface the most
    /// likely picks at the top of the picker.
    static var userPreferred: [LiveTranslationLanguage] {
        var seen: Set<LiveTranslationLanguage> = []
        var ordered: [LiveTranslationLanguage] = []
        for identifier in Locale.preferredLanguages {
            let locale = Locale(identifier: identifier)
            guard let code = locale.language.languageCode?.identifier,
                  let lang = LiveTranslationLanguage(rawValue: code),
                  !seen.contains(lang) else {
                continue
            }
            seen.insert(lang)
            ordered.append(lang)
        }
        return ordered
    }
}

/// Soniox `tts-rt-v1-preview` multilingual voices. Every voice can speak
/// every supported source/target language, so this is purely a timbre choice.
/// https://soniox.com/docs/tts/concepts/voices
enum LiveTranslationVoice: String, CaseIterable, Identifiable, Sendable {
    case adrian = "Adrian"
    case maya = "Maya"
    case daniel = "Daniel"
    case noah = "Noah"
    case nina = "Nina"
    case emma = "Emma"
    case jack = "Jack"
    case claire = "Claire"
    case grace = "Grace"
    case owen = "Owen"
    case mina = "Mina"
    case kenji = "Kenji"

    var id: String { rawValue }

    var displayName: String { rawValue }

    static let `default`: LiveTranslationVoice = .adrian
}

enum LiveTranslationStatus: Equatable, Sendable {
    case idle
    case starting
    case running
    case stopping
    case failed(String)
}

struct LiveTranslationToken: Sendable, Hashable {
    let id: UUID
    let text: String
    let isFinal: Bool
    let kind: Kind

    enum Kind: Sendable, Hashable {
        case original
        case translation
    }
}

struct LiveTranslationConfig: Sendable {
    var sourceLanguage: LiveTranslationLanguage
    var targetLanguage: LiveTranslationLanguage
    var ttsEnabled: Bool
    var ttsVoice: String
    var ttsRate: Float

    static var stored: LiveTranslationConfig {
        LiveTranslationConfig(
            sourceLanguage: LiveTranslationPreferences.sourceLanguage,
            targetLanguage: LiveTranslationPreferences.targetLanguage,
            ttsEnabled: LiveTranslationPreferences.ttsEnabled,
            ttsVoice: LiveTranslationPreferences.ttsVoice.rawValue,
            ttsRate: LiveTranslationPreferences.ttsRate
        )
    }
}

enum LiveTranslationPreferences {
    static let minTTSRate: Float = 1.0
    static let maxTTSRate: Float = 2.0
    static let defaultTTSRate: Float = 1.15

    static var sourceLanguage: LiveTranslationLanguage {
        get {
            let raw = UserDefaultsStorage.appPrivate.string(forKey: UserDefaultsStorage.Keys.liveTranslationSourceLanguage) ?? ""
            return LiveTranslationLanguage(rawValue: raw) ?? .english
        }
        set {
            UserDefaultsStorage.appPrivate.set(newValue.rawValue, forKey: UserDefaultsStorage.Keys.liveTranslationSourceLanguage)
        }
    }

    static var targetLanguage: LiveTranslationLanguage {
        get {
            let raw = UserDefaultsStorage.appPrivate.string(forKey: UserDefaultsStorage.Keys.liveTranslationTargetLanguage) ?? ""
            return LiveTranslationLanguage(rawValue: raw) ?? .english
        }
        set {
            UserDefaultsStorage.appPrivate.set(newValue.rawValue, forKey: UserDefaultsStorage.Keys.liveTranslationTargetLanguage)
        }
    }

    static var ttsEnabled: Bool {
        get {
            UserDefaultsStorage.appPrivate.object(forKey: UserDefaultsStorage.Keys.liveTranslationTTSEnabled) as? Bool ?? true
        }
        set {
            UserDefaultsStorage.appPrivate.set(newValue, forKey: UserDefaultsStorage.Keys.liveTranslationTTSEnabled)
        }
    }

    static var ttsRate: Float {
        get {
            let stored = UserDefaultsStorage.appPrivate.object(forKey: UserDefaultsStorage.Keys.liveTranslationTTSRate) as? Double
            let value = Float(stored ?? Double(defaultTTSRate))
            return min(max(value, minTTSRate), maxTTSRate)
        }
        set {
            let clamped = min(max(newValue, minTTSRate), maxTTSRate)
            UserDefaultsStorage.appPrivate.set(Double(clamped), forKey: UserDefaultsStorage.Keys.liveTranslationTTSRate)
        }
    }

    static var ttsVoice: LiveTranslationVoice {
        get {
            let raw = UserDefaultsStorage.appPrivate.string(forKey: UserDefaultsStorage.Keys.liveTranslationTTSVoice) ?? ""
            return LiveTranslationVoice(rawValue: raw) ?? .default
        }
        set {
            UserDefaultsStorage.appPrivate.set(newValue.rawValue, forKey: UserDefaultsStorage.Keys.liveTranslationTTSVoice)
        }
    }
}

enum LiveTranslationError: LocalizedError {
    case missingAPIKey
    case microphonePermissionDenied
    case audioSessionFailure(String)
    case webSocketFailure(String)
    case audioEngineFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Soniox API key is missing. Add it in Settings."
        case .microphonePermissionDenied:
            "Microphone access is required for live translation."
        case .audioSessionFailure(let message):
            "Audio session error: \(message)"
        case .webSocketFailure(let message):
            "Connection error: \(message)"
        case .audioEngineFailure(let message):
            "Audio error: \(message)"
        }
    }
}
