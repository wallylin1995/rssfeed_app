import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
#if canImport(Translation)
import Translation
#endif

struct ArticleSnapshot: Sendable {
    let title: String
    let sourceTitle: String
    let byline: String?
    let summary: String?
    let body: String

    init(article: ArticleRecord) {
        title = article.title
        sourceTitle = article.sourceTitle
        byline = article.byline ?? article.author
        summary = article.content?.summary
        body = article.content?.text ?? article.content?.summary ?? ""
    }

    init(content: ReaderArticleContent) {
        title = content.title
        sourceTitle = content.source
        byline = content.byline
        summary = content.excerpt
        body = content.bodyText
    }

    var summarizationInput: String {
        [
            "Title: \(title)",
            byline.flatMap { "Byline: \($0)" },
            "Source: \(sourceTitle)",
            summary.flatMap { "Feed Summary: \($0)" },
            "Article Body:",
            String(body.prefix(12_000))
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    var translationInput: String {
        String(body.prefix(16_000))
    }
}

struct ArticleTranslationResult: Sendable {
    let targetLanguageLabel: String
    let translatedTitle: String
    let translatedSummary: String?
    let translatedBody: String
}

enum ArticleIntelligenceError: LocalizedError {
    case missingArticleText
    case unableToDetectLanguage
    case appleIntelligenceUnavailable(String)
    case translationUnsupported(String)
    case frameworkUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingArticleText:
            "This article does not have enough local text to summarize or translate yet."
        case .unableToDetectLanguage:
            "Jippo could not reliably detect the source language for this article."
        case .appleIntelligenceUnavailable(let message),
             .translationUnsupported(let message),
             .frameworkUnavailable(let message):
            message
        }
    }
}

@MainActor
final class ArticleIntelligenceViewModel: ObservableObject {
    @Published var summary: String?
    @Published var translation: ArticleTranslationResult?
    @Published var isSummarizing = false
    @Published var isTranslating = false
    @Published var errorMessage: String?

    private var snapshot: ArticleSnapshot

    var hasOutput: Bool {
        let hasSummary = !(summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasSummary || translation != nil
    }

    var isBusy: Bool {
        isSummarizing || isTranslating
    }

    init(article: ArticleRecord) {
        snapshot = ArticleSnapshot(article: article)
    }

    func updateSnapshot(_ snapshot: ArticleSnapshot, resetOutputs: Bool = true) {
        self.snapshot = snapshot
        errorMessage = nil

        guard resetOutputs else { return }
        summary = nil
        translation = nil
    }

    func clearTranslation() {
        translation = nil
    }

    func clearOutputs() {
        summary = nil
        translation = nil
        errorMessage = nil
    }

    func summarize() async {
        guard !isSummarizing else { return }
        isSummarizing = true
        defer { isSummarizing = false }

        do {
            summary = try await ArticleIntelligenceService.summarize(snapshot: snapshot)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func translateToTraditionalChinese() async {
        await translate(to: Locale.Language(identifier: "zh-Hant"))
    }

    func translateToEnglish() async {
        await translate(to: Locale.Language(identifier: "en"))
    }

    private func translate(to targetLanguage: Locale.Language) async {
        guard !isTranslating else { return }
        isTranslating = true
        defer { isTranslating = false }

        do {
            translation = try await ArticleIntelligenceService.translate(snapshot: snapshot, targetLanguage: targetLanguage)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum ArticleIntelligenceService {
    static func summarize(snapshot: ArticleSnapshot) async throws -> String {
        guard !snapshot.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ArticleIntelligenceError.missingArticleText
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general, guardrails: .default)

            guard model.isAvailable else {
                throw ArticleIntelligenceError.appleIntelligenceUnavailable(availabilityMessage(for: model.availability))
            }

            let session = LanguageModelSession(
                model: model,
                instructions: """
                You are an editor inside a premium RSS reader.
                Summarize the article into:
                1. One sharp standfirst sentence.
                2. Three short bullet points.
                Keep it factual, concise, and readable.
                Preserve names, places, and numbers.
                Use the same language as the source article unless the article is Chinese, then keep Traditional Chinese.
                """
            )

            let response = try await session.respond(
                to: snapshot.summarizationInput,
                options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 280)
            )
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif

        throw ArticleIntelligenceError.frameworkUnavailable("Apple Intelligence summarize requires macOS 26 / iOS 26 or later.")
    }

    static func translate(snapshot: ArticleSnapshot, targetLanguage: Locale.Language) async throws -> ArticleTranslationResult {
        guard !snapshot.translationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ArticleIntelligenceError.missingArticleText
        }

        #if canImport(Translation)
        if #available(iOS 18.0, macOS 15.0, *) {
            let sourceLanguage = try detectedLanguage(for: snapshot)
            let availability = LanguageAvailability()
            let status = try await availability.status(for: snapshot.translationInput, to: targetLanguage)

            guard status != .unsupported else {
                throw ArticleIntelligenceError.translationUnsupported("This language pair is not supported by Apple Translation on this device yet.")
            }

            if sourceLanguage.minimalIdentifier == targetLanguage.minimalIdentifier {
                return ArticleTranslationResult(
                    targetLanguageLabel: localeLabel(for: targetLanguage),
                    translatedTitle: snapshot.title,
                    translatedSummary: snapshot.summary,
                    translatedBody: snapshot.translationInput
                )
            }

            let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            try await session.prepareTranslation()

            let requests = [
                TranslationSession.Request(sourceText: snapshot.title, clientIdentifier: "title"),
                TranslationSession.Request(sourceText: snapshot.summary ?? "", clientIdentifier: "summary"),
                TranslationSession.Request(sourceText: snapshot.translationInput, clientIdentifier: "body")
            ]

            let responses = try await session.translations(from: requests)
            let mapped: [String: String] = Dictionary(
                uniqueKeysWithValues: responses.map { (($0.clientIdentifier ?? ""), $0.targetText) }
            )

            return ArticleTranslationResult(
                targetLanguageLabel: localeLabel(for: targetLanguage),
                translatedTitle: mapped["title"] ?? snapshot.title,
                translatedSummary: snapshot.summary == nil ? nil : mapped["summary"],
                translatedBody: mapped["body"] ?? snapshot.translationInput
            )
        }
        #endif

        throw ArticleIntelligenceError.frameworkUnavailable("Apple Translation requires macOS 15 / iOS 18 or later.")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func availabilityMessage(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "Apple Intelligence is available."
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This device is not eligible for Apple Intelligence."
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled on this device."
            case .modelNotReady:
                return "Apple Intelligence is still preparing its on-device model."
            @unknown default:
                return "Apple Intelligence is temporarily unavailable on this device."
            }
        }
    }
    #endif

    private static func detectedLanguage(for snapshot: ArticleSnapshot) throws -> Locale.Language {
        #if canImport(NaturalLanguage)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString([snapshot.title, snapshot.summary, snapshot.translationInput]
            .compactMap { $0 }
            .joined(separator: "\n\n"))

        guard let dominantLanguage = recognizer.dominantLanguage else {
            throw ArticleIntelligenceError.unableToDetectLanguage
        }

        return Locale.Language(identifier: dominantLanguage.rawValue)
        #else
        throw ArticleIntelligenceError.frameworkUnavailable("NaturalLanguage is required to detect the source language for translation.")
        #endif
    }

    private static func localeLabel(for language: Locale.Language) -> String {
        let identifier = language.maximalIdentifier
        switch identifier {
        case let id where id.contains("zh-Hant"):
            return "繁體中文"
        case let id where id.hasPrefix("en"):
            return "English"
        default:
            return Locale.current.localizedString(forIdentifier: identifier) ?? identifier
        }
    }
}
