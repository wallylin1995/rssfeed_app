import SwiftUI
import WebKit
import Combine
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import SafariServices
#endif

struct EmbeddedArticleBrowserView: View {
    let article: ArticleRecord

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: ArticleWebViewStore
    @StateObject private var intelligence: ArticleIntelligenceViewModel
    @State private var mode: ArticlePresentationMode = .reader
    @AppStorage("reader.fontScale") private var fontScaleStorage = 1.0
    @AppStorage("reader.width") private var widthStorage = ReaderWidth.comfortable.rawValue
    @AppStorage("reader.theme") private var themeStorage = ReaderTheme.graphite.rawValue
    @State private var readerScrollOffset: CGFloat = 0
    @State private var insightPanelExpanded = false
    #if os(iOS)
    @State private var showingReaderSheet = false
    #endif

    init(article: ArticleRecord) {
        self.article = article
        _store = StateObject(
            wrappedValue: ArticleWebViewStore(
                articleURL: article.articleLink,
                fallbackContent: ReaderArticleContent.from(article: article)
            )
        )
        _intelligence = StateObject(wrappedValue: ArticleIntelligenceViewModel(article: article))
    }

    var body: some View {
        ZStack(alignment: .top) {
            let preferences = readerPreferences

            ZStack {
                if mode == .web {
                    PlatformWebView(webView: store.webView)
                        .background(preferences.theme.canvasColor)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.992)),
                                removal: .opacity
                            )
                        )
                }

                if mode == .reader {
                    ReaderModeView(content: store.readerContent, preferences: preferences, scrollOffset: $readerScrollOffset)
                        .background(preferences.theme.canvasColor)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.992)),
                                removal: .opacity
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.38, dampingFraction: 0.88), value: mode)

            VStack(spacing: 12) {
                floatingToolbar(preferences: preferences)

                if store.isLoading, mode == .web {
                    ProgressView(value: store.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(JippoPalette.highlight)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .glassPanel(cornerRadius: 18)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
        }
        .frame(minWidth: 1040, idealWidth: 1240, minHeight: 760, idealHeight: 900)
        .background(readerPreferences.theme.canvasColor.ignoresSafeArea())
        #if os(macOS)
        .background(WindowAutosaveConfigurator(autosaveName: "JippoArticleReaderWindow"))
        #endif
        #if os(iOS)
        .sheet(isPresented: $showingReaderSheet) {
            if let url = article.articleLink {
                SafariReaderSheet(url: url)
            }
        }
        #endif
    }

    private func floatingToolbar(preferences: ReaderPreferences) -> some View {
        let compact = mode == .reader && readerScrollOffset > 52

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .glassCapsuleButton()

                    Picker("View Mode", selection: $mode) {
                        ForEach(ArticlePresentationMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: compact ? 150 : 196)
                }
                .glassPanel(cornerRadius: compact ? 18 : 22)

                if mode == .web {
                    HStack(spacing: 10) {
                        Button {
                            store.goBack()
                        } label: {
                            Image(systemName: "chevron.backward")
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .glassCapsuleButton()
                        .disabled(!store.canGoBack)

                        Button {
                            store.goForward()
                        } label: {
                            Image(systemName: "chevron.forward")
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .glassCapsuleButton()
                        .disabled(!store.canGoForward)

                        Button {
                            store.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .glassCapsuleButton()
                    }
                    .glassPanel(cornerRadius: compact ? 18 : 22)
                } else {
                    readerPreferencesToolbar(compact: compact)
                }

                intelligenceToolbar(compact: compact, preferences: preferences)

                Spacer(minLength: 0)

                if !compact {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(store.readerContent.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(preferences.theme.primaryTextColor)

                        HStack(spacing: 8) {
                            Text(store.readerContent.source)

                            if let author = store.readerContent.byline ?? article.byline ?? article.author {
                                Text("•")
                                Text(author)
                                    .lineLimit(1)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(preferences.theme.secondaryTextColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassPanel(cornerRadius: 22)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                #if os(iOS)
                if article.articleLink != nil {
                    Button("Safari Reader") {
                        showingReaderSheet = true
                    }
                    .buttonStyle(.glassProminentOrFallback(tint: JippoPalette.highlight))
                }
                #endif
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: compact)

            if insightPanelExpanded || intelligence.isSummarizing || intelligence.isTranslating || intelligence.hasOutput || intelligence.errorMessage != nil {
                intelligencePanel(preferences: preferences, compact: compact)
                    .frame(maxWidth: compact ? 420 : 560, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func readerPreferencesToolbar(compact: Bool) -> some View {
        HStack(spacing: 10) {
            preferenceChip(label: "A-", action: { fontScaleStorage = max(0.88, fontScaleStorage - 0.08) })
            preferenceChip(label: "A+", action: { fontScaleStorage = min(1.4, fontScaleStorage + 0.08) })

            Picker("Width", selection: readerWidthBinding) {
                ForEach(ReaderWidth.allCases) { width in
                    Text(width.shortLabel).tag(width)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: compact ? 120 : 160)

            Picker("Theme", selection: readerThemeBinding) {
                ForEach(ReaderTheme.allCases) { theme in
                    Text(theme.shortLabel).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: compact ? 132 : 170)
        }
        .glassPanel(cornerRadius: compact ? 18 : 22)
    }

    private func preferenceChip(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 38, minHeight: 30)
        }
        .buttonStyle(.plain)
        .glassCapsuleButton()
    }

    private func intelligenceToolbar(compact: Bool, preferences: ReaderPreferences) -> some View {
        HStack(spacing: 8) {
            intelligenceChip(
                label: compact ? "AI" : "摘要",
                systemImage: "sparkles",
                accent: preferences.theme.accentColor
            ) {
                insightPanelExpanded = true
                Task { await intelligence.summarize() }
            }

            intelligenceChip(
                label: compact ? "繁" : "繁中",
                systemImage: "character.book.closed",
                accent: preferences.theme.accentColor.opacity(0.82)
            ) {
                insightPanelExpanded = true
                Task { await intelligence.translateToTraditionalChinese() }
            }

            intelligenceChip(
                label: compact ? "EN" : "English",
                systemImage: "globe",
                accent: preferences.theme.accentColor.opacity(0.62)
            ) {
                insightPanelExpanded = true
                Task { await intelligence.translateToEnglish() }
            }

            if intelligence.hasOutput || intelligence.errorMessage != nil {
                intelligenceChip(
                    label: compact ? "×" : "Clear",
                    systemImage: "xmark",
                    accent: preferences.theme.secondaryTextColor.opacity(0.18)
                ) {
                    intelligence.clearOutputs()
                    insightPanelExpanded = false
                }
            }

            if intelligence.isSummarizing || intelligence.isTranslating {
                ProgressView()
                    .controlSize(.small)
                    .tint(preferences.theme.accentColor)
                    .padding(.horizontal, 4)
            }
        }
        .glassPanel(cornerRadius: compact ? 18 : 22)
    }

    private func intelligenceChip(label: String, systemImage: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(accent.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .glassCapsuleButton()
    }

    private func intelligencePanel(preferences: ReaderPreferences, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(activeInsightTitle, systemImage: activeInsightIcon)
                    .font(.caption.weight(.black))
                    .kerning(1.2)
                    .foregroundStyle(preferences.theme.accentColor)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        insightPanelExpanded.toggle()
                    }
                } label: {
                    Image(systemName: insightPanelExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .glassCapsuleButton()
            }

            if let errorMessage = intelligence.errorMessage {
                Text(errorMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(preferences.theme.secondaryTextColor)
            } else if insightPanelExpanded || intelligence.hasOutput || intelligence.isSummarizing || intelligence.isTranslating {
                Text(activeInsightText)
                    .font(.system(size: compact ? 16 : 18, weight: .medium, design: .serif))
                    .lineSpacing(compact ? 5 : 7)
                    .foregroundStyle(preferences.theme.primaryTextColor)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassPanel(cornerRadius: compact ? 22 : 24)
    }

    private var activeInsightTitle: String {
        if let translation = intelligence.translation {
            return "TRANSLATION · \(translation.targetLanguageLabel.uppercased())"
        }
        return "APPLE INTELLIGENCE SUMMARY"
    }

    private var activeInsightIcon: String {
        intelligence.translation == nil ? "sparkles" : "text.bubble"
    }

    private var activeInsightText: String {
        if let translation = intelligence.translation {
            let body = translation.translatedBody.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = translation.translatedSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let summary, !summary.isEmpty {
                return "\(translation.translatedTitle)\n\n\(summary)"
            }
            return body.isEmpty ? translation.translatedTitle : "\(translation.translatedTitle)\n\n\(String(body.prefix(420)))"
        }

        return intelligence.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Generate a concise takeaway from this article."
    }

    private var readerPreferences: ReaderPreferences {
        ReaderPreferences(
            fontScale: CGFloat(fontScaleStorage),
            width: ReaderWidth(rawValue: widthStorage) ?? .comfortable,
            theme: ReaderTheme(rawValue: themeStorage) ?? .graphite
        )
    }

    private var readerWidthBinding: Binding<ReaderWidth> {
        Binding(
            get: { ReaderWidth(rawValue: widthStorage) ?? .comfortable },
            set: { widthStorage = $0.rawValue }
        )
    }

    private var readerThemeBinding: Binding<ReaderTheme> {
        Binding(
            get: { ReaderTheme(rawValue: themeStorage) ?? .graphite },
            set: { themeStorage = $0.rawValue }
        )
    }
}

private enum ArticlePresentationMode: String, CaseIterable, Identifiable {
    case reader
    case web

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reader:
            return "閱讀模式"
        case .web:
            return "原文"
        }
    }
}

private struct ReaderPreferences {
    var fontScale: CGFloat = 1
    var width: ReaderWidth = .comfortable
    var theme: ReaderTheme = .graphite
}

private enum ReaderWidth: String, CaseIterable, Identifiable {
    case focused
    case comfortable
    case expansive

    var id: String { rawValue }

    var maxWidth: CGFloat {
        switch self {
        case .focused: 720
        case .comfortable: 860
        case .expansive: 980
        }
    }

    var shortLabel: String {
        switch self {
        case .focused: "窄"
        case .comfortable: "中"
        case .expansive: "寬"
        }
    }
}

private enum ReaderTheme: String, CaseIterable, Identifiable {
    case graphite
    case paper
    case sepia

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .graphite: "深色"
        case .paper: "白紙"
        case .sepia: "暖紙"
        }
    }

    var canvasColor: Color {
        switch self {
        case .graphite: Color(red: 0.09, green: 0.10, blue: 0.12)
        case .paper: Color(red: 0.93, green: 0.92, blue: 0.89)
        case .sepia: Color(red: 0.94, green: 0.89, blue: 0.80)
        }
    }

    var articleSurfaceColor: Color {
        switch self {
        case .graphite: Color(red: 0.15, green: 0.16, blue: 0.19)
        case .paper: Color.white.opacity(0.82)
        case .sepia: Color(red: 0.97, green: 0.92, blue: 0.84)
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .graphite: .white
        case .paper, .sepia: Color.black.opacity(0.84)
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .graphite: .white.opacity(0.7)
        case .paper, .sepia: Color.black.opacity(0.55)
        }
    }

    var accentColor: Color {
        switch self {
        case .graphite: JippoPalette.highlight
        case .paper: Color(red: 0.70, green: 0.26, blue: 0.34)
        case .sepia: Color(red: 0.66, green: 0.36, blue: 0.20)
        }
    }

    var codeBackground: Color {
        switch self {
        case .graphite: Color.white.opacity(0.08)
        case .paper: Color.black.opacity(0.05)
        case .sepia: Color.black.opacity(0.06)
        }
    }
}

private struct ReaderModeView: View {
    let content: ReaderArticleContent
    let preferences: ReaderPreferences
    @Binding var scrollOffset: CGFloat
    @State private var galleryPresentation: ReaderGalleryPresentation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ReaderScrollOffsetKey.self, value: -proxy.frame(in: .named("readerScroll")).minY)
                }
                .frame(height: 0)

                if let heroImageURL = content.heroImageURL {
                    AsyncImage(url: heroImageURL) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Rectangle()
                                    .fill(JippoPalette.panelSoft)
                                ProgressView()
                            }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle()
                                .fill(JippoPalette.panelSoft)
                        @unknown default:
                            Rectangle()
                                .fill(JippoPalette.panelSoft)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(content.source)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.86))

                                Text(content.title)
                                    .font(.system(size: 46 * preferences.fontScale, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(28)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 18) {
                    if content.heroImageURL == nil {
                        Text(content.source)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(preferences.theme.accentColor)

                        Text(content.title)
                            .font(.system(size: 44 * preferences.fontScale, weight: .bold, design: .rounded))
                            .foregroundStyle(preferences.theme.primaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        if let byline = content.byline, !byline.isEmpty {
                            Text(byline)
                        }

                        if let readingTime = content.readingTime {
                            if content.byline?.isEmpty == false {
                                Text("•")
                            }
                            Text(readingTime)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(preferences.theme.secondaryTextColor)

                    if let excerpt = content.excerpt, !excerpt.isEmpty {
                        Text(excerpt)
                            .font(.system(size: 22 * preferences.fontScale, weight: .medium, design: .serif))
                            .foregroundStyle(preferences.theme.secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()
                    .overlay(preferences.theme.secondaryTextColor.opacity(0.18))

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(content.blocks.enumerated()), id: \.offset) { _, block in
                        ReaderBlockView(
                            block: block,
                            preferences: preferences,
                            openGallery: { items, index in
                                galleryPresentation = ReaderGalleryPresentation(items: items, selectedIndex: index)
                            }
                        )
                    }
                }

                if content.blocks.isEmpty {
                    Text("This article does not expose a clean article body yet, so Jippo is falling back to the feed summary.")
                        .font(.body)
                        .foregroundStyle(preferences.theme.secondaryTextColor)
                }
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 88)
            .frame(maxWidth: preferences.width.maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(preferences.theme.articleSurfaceColor)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 28)
            )
        }
        .coordinateSpace(name: "readerScroll")
        .onPreferenceChange(ReaderScrollOffsetKey.self) { scrollOffset = $0 }
        .scrollContentBackground(.hidden)
        .background(preferences.theme.canvasColor)
        .sheet(item: $galleryPresentation) { presentation in
            ReaderGalleryLightbox(
                items: presentation.items,
                initialIndex: presentation.selectedIndex,
                theme: preferences.theme
            )
        }
    }
}

struct ReaderArticleContent {
    var title: String
    var source: String
    var byline: String?
    var excerpt: String?
    var heroImageURL: URL?
    var blocks: [ReaderBlock]
    var bodyText: String

    var readingTime: String? {
        let words = bodyText.split { $0.isWhitespace || $0.isNewline }.count
        guard words > 0 else { return nil }
        let minutes = max(1, Int(ceil(Double(words) / 220)))
        return "\(minutes) min read"
    }

    static func from(article: ArticleRecord) -> ReaderArticleContent {
        let summary = normalizedPlainText(from: article.content?.summary)
        let htmlText = normalizedPlainText(fromHTML: article.content?.html)
        let body = normalizedPlainText(from: article.content?.text) ?? htmlText ?? summary ?? ""

        return ReaderArticleContent(
            title: article.title,
            source: article.sourceTitle,
            byline: cleaned(article.byline) ?? cleaned(article.author),
            excerpt: summary,
            heroImageURL: article.imageLink,
            blocks: blocks(from: body),
            bodyText: body
        )
    }

    static func blocks(from body: String) -> [ReaderBlock] {
        body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ReaderBlock(kind: .paragraph, text: $0, imageURL: nil, mediaItems: [], caption: nil, language: nil) }
    }

    static func decodeBlocks(from json: String?) -> [ReaderBlock]? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode([ReaderBlockPayload].self, from: data) else { return nil }

        let blocks = payload.compactMap { item -> ReaderBlock? in
            guard let kind = ReaderBlock.Kind(rawValue: item.kind) else { return nil }
            let text = cleaned(item.text) ?? ""
            let caption = cleaned(item.caption)
            let resolvedImageURL = imageURL(from: item.imageURL)
            let language = cleaned(item.language)
            let mediaItems = item.mediaItems?.compactMap { payload -> ReaderMediaItem? in
                let url = imageURL(from: payload.imageURL)
                let caption = cleaned(payload.caption)
                guard url != nil || caption != nil else { return nil }
                return ReaderMediaItem(imageURL: url, caption: caption)
            } ?? []

            if kind != .image && kind != .caption && kind != .codeBlock && text.isEmpty {
                return nil
            }

            if kind == .image && resolvedImageURL == nil {
                return nil
            }

            if kind == .imageGallery && mediaItems.isEmpty {
                return nil
            }

            return ReaderBlock(
                kind: kind,
                text: text,
                imageURL: resolvedImageURL,
                mediaItems: mediaItems,
                caption: caption,
                language: language
            )
        }

        return blocks.isEmpty ? nil : blocks
    }

    static func imageURL(from string: String?) -> URL? {
        guard let cleaned = cleaned(string), let url = URL(string: cleaned) else { return nil }
        return url
    }

    static func normalizedPlainText(from text: String?) -> String? {
        guard let text = cleaned(text) else { return nil }

        if text.contains("<"), text.contains(">") {
            return normalizedPlainText(fromHTML: text)
        }

        return text
    }

    static func normalizedPlainText(fromHTML html: String?) -> String? {
        guard let html = cleaned(html) else { return nil }
        return cleaned(HTMLContentExtractor.plainText(from: html))
    }

    static func cleaned(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ReaderBlock {
    var kind: Kind
    var text: String
    var imageURL: URL?
    var mediaItems: [ReaderMediaItem]
    var caption: String?
    var language: String?

    enum Kind: String {
        case heading
        case subheading
        case paragraph
        case pullQuote
        case listItem
        case image
        case imageGallery
        case caption
        case codeBlock
    }
}

private struct ReaderBlockPayload: Decodable {
    let kind: String
    let text: String
    let imageURL: String?
    let mediaItems: [ReaderMediaItemPayload]?
    let caption: String?
    let language: String?
}

struct ReaderMediaItem: Decodable, Hashable {
    let imageURL: URL?
    let caption: String?
}

private struct ReaderMediaItemPayload: Decodable {
    let imageURL: String?
    let caption: String?
}

private struct ReaderScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ReaderGalleryPresentation: Identifiable {
    let id = UUID()
    let items: [ReaderMediaItem]
    let selectedIndex: Int
}

private struct ReaderBlockView: View {
    let block: ReaderBlock
    let preferences: ReaderPreferences
    let openGallery: ([ReaderMediaItem], Int) -> Void

    var body: some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .font(.system(size: 30 * preferences.fontScale, weight: .bold, design: .rounded))
                .padding(.top, 10)
                .foregroundStyle(preferences.theme.primaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .subheading:
            Text(block.text)
                .font(.system(size: 24 * preferences.fontScale, weight: .semibold, design: .rounded))
                .foregroundStyle(preferences.theme.primaryTextColor.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .paragraph:
            Text(block.text)
                .font(.system(size: 21 * preferences.fontScale, weight: .regular, design: .serif))
                .lineSpacing(8)
                .foregroundStyle(preferences.theme.primaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .pullQuote:
            VStack(alignment: .leading, spacing: 8) {
                Text(block.text)
                    .font(.system(size: 28 * preferences.fontScale, weight: .medium, design: .serif))
                    .italic()
                    .lineSpacing(9)
                    .foregroundStyle(preferences.theme.primaryTextColor.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let caption = block.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(preferences.theme.secondaryTextColor)
                }
            }
            .padding(.leading, 22)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(preferences.theme.accentColor.opacity(0.85))
                    .frame(width: 4)
            }
        case .listItem:
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(preferences.theme.accentColor.opacity(0.85))
                    .frame(width: 7, height: 7)
                    .padding(.top, 10)

                Text(block.text)
                    .font(.system(size: 20 * preferences.fontScale, weight: .regular, design: .serif))
                    .lineSpacing(7)
                    .foregroundStyle(preferences.theme.primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        case .image:
            VStack(alignment: .leading, spacing: 10) {
                if let imageURL = block.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(preferences.theme.codeBackground)
                                ProgressView()
                            }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(preferences.theme.codeBackground)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(preferences.theme.secondaryTextColor)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .onTapGesture {
                        openGallery([ReaderMediaItem(imageURL: imageURL, caption: block.caption)], 0)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                if let caption = block.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(preferences.theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .imageGallery:
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: galleryColumns, spacing: 12) {
                    ForEach(Array(block.mediaItems.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 8) {
                            if let url = item.imageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .fill(preferences.theme.codeBackground)
                                            ProgressView()
                                        }
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(preferences.theme.codeBackground)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(height: 220)
                                .onTapGesture {
                                    openGallery(block.mediaItems, index)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }

                            if let caption = item.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.caption)
                                    .foregroundStyle(preferences.theme.secondaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if let caption = block.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(preferences.theme.secondaryTextColor)
                }
            }
        case .caption:
            Text(block.text)
                .font(.caption)
                .foregroundStyle(preferences.theme.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        case .codeBlock:
            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.text)
                    .font(.system(size: 15 * preferences.fontScale, weight: .regular, design: .monospaced))
                    .foregroundStyle(preferences.theme.primaryTextColor)
                    .textSelection(.enabled)
                    .padding(18)
            }
            .background(preferences.theme.codeBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var galleryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
}

private struct ReaderGalleryLightbox: View {
    @Environment(\.dismiss) private var dismiss
    let items: [ReaderMediaItem]
    let initialIndex: Int
    let theme: ReaderTheme
    @State private var selectedIndex: Int
    @State private var dismissDragOffset: CGSize = .zero
    @State private var chromeVisible = true

    init(items: [ReaderMediaItem], initialIndex: Int, theme: ReaderTheme) {
        self.items = items
        self.initialIndex = initialIndex
        self.theme = theme
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            theme.canvasColor
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 18) {
                        Spacer(minLength: 0)

                        if let url = item.imageURL {
                            ZoomableGalleryImage(
                                url: url,
                                theme: theme,
                                onDismissDragChanged: { translation in
                                    dismissDragOffset = translation
                                    setChromeVisible(abs(translation.height) < 12)
                                },
                                onDismissDragEnded: { translation in
                                    finishDismissDrag(translation: translation)
                                },
                                onInteractionChanged: { interacting in
                                    setChromeVisible(!interacting)
                                }
                            )
                            .padding(.horizontal, 28)
                        }

                        if let caption = item.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.body)
                                .foregroundStyle(theme.secondaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 60)
                                .padding(.bottom, 32)
                        } else {
                            Spacer(minLength: 32)
                        }
                    }
                    .tag(index)
                }
            }
            .modifier(GalleryTabViewStyle())
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: selectedIndex)
            .offset(y: dismissDragOffset.height * 0.18)
            .scaleEffect(1 - min(abs(dismissDragOffset.height) / 1800, 0.045))

            HStack {
                galleryArrowButton(systemName: "chevron.left", enabled: selectedIndex > 0) {
                    selectedIndex = max(0, selectedIndex - 1)
                }

                Spacer()

                galleryArrowButton(systemName: "chevron.right", enabled: selectedIndex < items.count - 1) {
                    selectedIndex = min(items.count - 1, selectedIndex + 1)
                }
            }
            .padding(.horizontal, 24)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .glassCapsuleButton()

                Spacer()

                Text("\(selectedIndex + 1) / \(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.primaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .glassPanel(cornerRadius: 18)
            }
            .padding(18)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: chromeVisible)
        #if os(macOS)
        .background(
            LightboxKeyboardHandler(
                onLeft: { if selectedIndex > 0 { selectedIndex -= 1 } },
                onRight: { if selectedIndex < items.count - 1 { selectedIndex += 1 } },
                onEscape: { dismiss() },
                onSpace: { chromeVisible.toggle() }
            )
        )
        #endif
    }

    private func galleryArrowButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .glassCapsuleButton()
        .opacity(enabled ? 1 : 0.32)
        .disabled(!enabled)
    }

    private var backgroundOpacity: Double {
        let fade = min(abs(dismissDragOffset.height) / 260, 0.4)
        return max(0.58, 1 - fade)
    }

    private func finishDismissDrag(translation: CGSize) {
        if abs(translation.height) > 140 {
            dismiss()
        } else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                dismissDragOffset = .zero
            }
            setChromeVisible(true)
        }
    }

    private func setChromeVisible(_ visible: Bool) {
        guard chromeVisible != visible else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
            chromeVisible = visible
        }
    }
}

private struct GalleryTabViewStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.tabViewStyle(.page(indexDisplayMode: .automatic))
        #else
        content.tabViewStyle(.automatic)
        #endif
    }
}

private struct ZoomableGalleryImage: View {
    let url: URL
    let theme: ReaderTheme
    let onDismissDragChanged: (CGSize) -> Void
    let onDismissDragEnded: (CGSize) -> Void
    let onInteractionChanged: (Bool) -> Void

    @State private var baseScale: CGFloat = 1
    @State private var pinchScale: CGFloat = 1
    @State private var baseOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    private var effectiveScale: CGFloat {
        min(max(baseScale * pinchScale, 1), 4)
    }

    private var effectiveOffset: CGSize {
        CGSize(width: baseOffset.width + dragOffset.width, height: baseOffset.height + dragOffset.height)
    }

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(effectiveScale)
                        .offset(effectiveOffset)
                        .contentShape(Rectangle())
                        .gesture(doubleTapGesture(containerSize: proxy.size))
                        .simultaneousGesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: effectiveScale)
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.secondaryTextColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinchScale = value.magnification
                onInteractionChanged(true)
            }
            .onEnded { value in
                baseScale = min(max(baseScale * value.magnification, 1), 4)
                pinchScale = 1
                if baseScale <= 1.02 {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        resetPan()
                    }
                    onInteractionChanged(false)
                } else {
                    onInteractionChanged(true)
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if effectiveScale > 1.02 {
                    dragOffset = value.translation
                    onDismissDragChanged(.zero)
                    onInteractionChanged(true)
                } else {
                    dragOffset = .zero
                    onDismissDragChanged(value.translation)
                    onInteractionChanged(true)
                }
            }
            .onEnded { value in
                if effectiveScale > 1.02 {
                    baseOffset = CGSize(
                        width: baseOffset.width + value.translation.width,
                        height: baseOffset.height + value.translation.height
                    )
                    dragOffset = .zero
                    onInteractionChanged(true)
                } else {
                    dragOffset = .zero
                    onDismissDragEnded(value.translation)
                    onInteractionChanged(false)
                }
            }
    }

    private func doubleTapGesture(containerSize: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                    if effectiveScale > 1.2 {
                        baseScale = 1
                        pinchScale = 1
                        resetPan()
                        onInteractionChanged(false)
                    } else {
                        baseScale = 2.2
                        pinchScale = 1
                        baseOffset = zoomOffset(for: value.location, in: containerSize, scale: baseScale)
                        dragOffset = .zero
                        onInteractionChanged(true)
                    }
                }
            }
    }

    private func resetPan() {
        baseOffset = .zero
        dragOffset = .zero
    }

    private func zoomOffset(for location: CGPoint, in size: CGSize, scale: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let x = (center.x - location.x) * min(scale - 1, 1.4) * 0.72
        let y = (center.y - location.y) * min(scale - 1, 1.4) * 0.72
        return CGSize(width: x, height: y)
    }
}

#if os(macOS)
private struct LightboxKeyboardHandler: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onEscape: () -> Void
    let onSpace: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLeft: onLeft, onRight: onRight, onEscape: onEscape, onSpace: onSpace)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
    }

    final class Coordinator {
        private let onLeft: () -> Void
        private let onRight: () -> Void
        private let onEscape: () -> Void
        private let onSpace: () -> Void
        private weak var hostingView: NSView?
        private var monitor: Any?

        init(onLeft: @escaping () -> Void, onRight: @escaping () -> Void, onEscape: @escaping () -> Void, onSpace: @escaping () -> Void) {
            self.onLeft = onLeft
            self.onRight = onRight
            self.onEscape = onEscape
            self.onSpace = onSpace
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func attach(to view: NSView) {
            hostingView = view
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }

            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.hostingView?.window?.isKeyWindow == true else { return event }

                switch event.keyCode {
                case 123:
                    self.onLeft()
                    return nil
                case 124:
                    self.onRight()
                    return nil
                case 53:
                    self.onEscape()
                    return nil
                case 49:
                    self.onSpace()
                    return nil
                default:
                    return event
                }
            }
        }
    }
}

private struct WindowAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWindow(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(from: nsView)
    }

    private func configureWindow(from view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.setFrameAutosaveName(autosaveName)
            window.isRestorable = true
            window.collectionBehavior.insert(.fullScreenPrimary)
        }
    }
}
#endif

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
    }
}

private struct GlassCapsuleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
    }
}

private struct GlassProminentOrFallback: PrimitiveButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        Button(role: nil, action: configuration.trigger) {
            configuration.label
        }
        .tint(tint)
        .modifier(GlassProminentButtonModifier(tint: tint))
    }
}

private struct GlassProminentButtonModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(tint, in: Capsule())
                .foregroundStyle(.white)
        }
    }
}

private extension View {
    func glassPanel(cornerRadius: CGFloat) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }

    func glassCapsuleButton() -> some View {
        modifier(GlassCapsuleButtonModifier())
    }
}

private extension PrimitiveButtonStyle where Self == GlassProminentOrFallback {
    static func glassProminentOrFallback(tint: Color) -> GlassProminentOrFallback {
        GlassProminentOrFallback(tint: tint)
    }
}

private enum ReadabilityScriptLoader {
    static func script() -> String? {
        guard let url = Bundle.main.url(
            forResource: "Readability",
            withExtension: "js",
            subdirectory: "Vendor"
        ) else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }
}

@MainActor
final class ArticleWebViewStore: NSObject, ObservableObject {
    let webView: WKWebView

    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = true
    @Published var pageTitle: String?
    @Published var currentURL: URL?
    @Published var readerContent: ReaderArticleContent

    private var cancellables: Set<AnyCancellable> = []

    init(articleURL: URL?, fallbackContent: ReaderArticleContent) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        self.readerContent = fallbackContent
        super.init()

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        currentURL = articleURL

        observeWebView()

        if let articleURL {
            load(url: articleURL)
        } else {
            isLoading = false
        }
    }

    func presentArticle(url: URL?, fallbackContent: ReaderArticleContent) {
        readerContent = fallbackContent
        estimatedProgress = 0
        isLoading = url != nil
        pageTitle = nil
        canGoBack = false
        canGoForward = false
        currentURL = url
        webView.stopLoading()

        guard let url else {
            isLoading = false
            return
        }

        load(url: url)
    }

    func load(url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        currentURL = url
        webView.load(request)
    }

    func reload() {
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    private func observeWebView() {
        webView.publisher(for: \.estimatedProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.estimatedProgress = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoBack)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canGoBack = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoForward)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canGoForward = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isLoading = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.title)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.pageTitle = $0 }
            .store(in: &cancellables)

        webView.publisher(for: \.url)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.currentURL = $0 }
            .store(in: &cancellables)
    }

    private func refreshReaderContentFromPage() {
        #if os(macOS)
        if let readabilityScript = ReadabilityScriptLoader.script() {
            refreshReaderContentWithReadability(script: readabilityScript)
            return
        }
        #endif

        refreshReaderContentWithDOMFallback()
    }

    #if os(macOS)
    private func refreshReaderContentWithReadability(script readabilityScript: String) {
        let script = """
        \(readabilityScript)
        (() => {
          const clonedDocument = document.cloneNode(true);
          const article = new Readability(clonedDocument).parse();

          if (!article) {
            return null;
          }

          const parser = new DOMParser();
          const parsed = parser.parseFromString(article.content || "", "text/html");
          const root = parsed.body;
          const blocks = [];
          const pushBlock = (kind, text, extra = {}) => {
            const raw = text || "";
            const cleaned = kind === "codeBlock"
              ? raw.replace(/^\\n+|\\n+$/g, "")
              : raw.replace(/\\s+/g, " ").trim();

            if (cleaned || extra.imageURL || (extra.mediaItems && extra.mediaItems.length)) {
              blocks.push({ kind, text: cleaned, ...extra });
            }
          };

          root.querySelectorAll("script, style, noscript").forEach(node => node.remove());

          const walk = node => {
            if (!node || node.nodeType !== Node.ELEMENT_NODE) return;
            const tag = node.tagName.toLowerCase();

            const directImages = Array.from(node.querySelectorAll(":scope > img"));
            if ((tag === "figure" || node.className?.toLowerCase().includes("gallery")) && directImages.length > 1) {
              pushBlock("imageGallery", "", {
                mediaItems: directImages.map(image => ({
                  imageURL: image.getAttribute("src") || "",
                  caption: image.getAttribute("alt") || ""
                })),
                caption: node.querySelector("figcaption")?.textContent || ""
              });
              return;
            }

            if (tag === "figure") {
                const image = node.querySelector("img");
                if (image) {
                  pushBlock("image", "", {
                  imageURL: image.getAttribute("src") || "",
                  caption: node.querySelector("figcaption")?.textContent || ""
                });
              }
              return;
            }

            if (tag === "img") {
              pushBlock("image", "", {
                imageURL: node.getAttribute("src") || "",
                caption: node.getAttribute("alt") || ""
              });
              return;
            }

            if (tag === "pre") {
              const code = node.querySelector("code");
              pushBlock("codeBlock", code?.innerText || node.innerText || "", {
                language: code?.className || ""
              });
              return;
            }

            if (tag === "blockquote") {
              pushBlock("pullQuote", node.textContent, {
                caption: node.querySelector("cite")?.textContent || ""
              });
              return;
            }

            if (tag === "h1" || tag === "h2") {
              pushBlock("heading", node.textContent);
              return;
            }

            if (tag === "h3" || tag === "h4") {
              pushBlock("subheading", node.textContent);
              return;
            }

            if (tag === "ul" || tag === "ol") {
              Array.from(node.children).forEach(item => pushBlock("listItem", item.textContent));
              return;
            }

            if (tag === "p") {
              const loneImage = node.querySelector("img");
              if (loneImage && node.textContent.trim() === (loneImage.getAttribute("alt") || "").trim()) {
                pushBlock("image", "", {
                  imageURL: loneImage.getAttribute("src") || "",
                  caption: loneImage.getAttribute("alt") || ""
                });
              } else {
                pushBlock("paragraph", node.textContent);
              }
              return;
            }

            if (tag === "figcaption") {
              pushBlock("caption", node.textContent);
              return;
            }

            const children = Array.from(node.children);
            if (children.length === 0) {
              pushBlock("paragraph", node.textContent);
              return;
            }

            children.forEach(walk);
          };

          Array.from(root.children).forEach(walk);

          const heroImage =
            parsed.querySelector("img")?.getAttribute("src") ||
            document.querySelector('meta[property="og:image"]')?.content ||
            document.querySelector('meta[name="twitter:image"]')?.content ||
            "";

          return {
            title: article.title || document.title || "",
            excerpt: article.excerpt || "",
            byline: article.byline || "",
            siteName: article.siteName || "",
            heroImage: heroImage,
            bodyText: article.textContent || "",
            blocksJSON: JSON.stringify(blocks)
          };
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] value, _ in
            guard let self else { return }
            guard let payload = value as? [String: Any] else {
                self.refreshReaderContentWithDOMFallback()
                return
            }

            let pageText = ReaderArticleContent.cleaned(payload["bodyText"] as? String)
            guard let pageText, pageText.count > 280 else {
                self.refreshReaderContentWithDOMFallback()
                return
            }

            self.readerContent = ReaderArticleContent(
                title: ReaderArticleContent.cleaned(payload["title"] as? String) ?? self.readerContent.title,
                source: ReaderArticleContent.cleaned(payload["siteName"] as? String) ?? self.readerContent.source,
                byline: ReaderArticleContent.cleaned(payload["byline"] as? String) ?? self.readerContent.byline,
                excerpt: ReaderArticleContent.cleaned(payload["excerpt"] as? String) ?? self.readerContent.excerpt,
                heroImageURL: ReaderArticleContent.imageURL(from: payload["heroImage"] as? String) ?? self.readerContent.heroImageURL,
                blocks: ReaderArticleContent.decodeBlocks(from: payload["blocksJSON"] as? String) ?? ReaderArticleContent.blocks(from: pageText),
                bodyText: pageText
            )
        }
    }
    #endif

    private func refreshReaderContentWithDOMFallback() {
        let script = """
        (() => {
          const pick = (...selectors) => {
            for (const selector of selectors) {
              const node = document.querySelector(selector);
              if (node) return node;
            }
            return null;
          };

          const title =
            document.querySelector('meta[property="og:title"]')?.content ||
            document.querySelector('meta[name="twitter:title"]')?.content ||
            document.title ||
            "";

          const excerpt =
            document.querySelector('meta[property="og:description"]')?.content ||
            document.querySelector('meta[name="description"]')?.content ||
            "";

          const byline =
            document.querySelector('meta[name="author"]')?.content ||
            pick('[rel="author"]', '.byline', '.article-byline', '.author', '[itemprop="author"]')?.innerText ||
            "";

          const bodyNode = pick(
            'article',
            'main article',
            'main',
            '[role="main"]',
            '.article-body',
            '.entry-content',
            '.post-content',
            '.story-body'
          ) || document.body;

          const bodyText = (bodyNode?.innerText || "")
            .replace(/\\n{3,}/g, '\\n\\n')
            .trim();
          const blocks = [];
          const pushBlock = (kind, text, extra = {}) => {
            const cleaned = (text || "").replace(/\\s+/g, " ").trim();
            if (cleaned || extra.imageURL || (extra.mediaItems && extra.mediaItems.length)) {
              blocks.push({ kind, text: cleaned, ...extra });
            }
          };

          const walk = node => {
            if (!node || node.nodeType !== Node.ELEMENT_NODE) return;
            const tag = node.tagName.toLowerCase();

            const directImages = Array.from(node.querySelectorAll(":scope > img"));
            if ((tag === "figure" || node.className?.toLowerCase().includes("gallery")) && directImages.length > 1) {
              pushBlock("imageGallery", "", {
                mediaItems: directImages.map(image => ({
                  imageURL: image.getAttribute("src") || "",
                  caption: image.getAttribute("alt") || ""
                })),
                caption: node.querySelector("figcaption")?.textContent || ""
              });
              return;
            }

            if (tag === "figure") {
              const image = node.querySelector("img");
              if (image) {
                pushBlock("image", "", {
                  imageURL: image.getAttribute("src") || "",
                  caption: node.querySelector("figcaption")?.textContent || ""
                });
              }
              return;
            }

            if (tag === "img") {
              pushBlock("image", "", {
                imageURL: node.getAttribute("src") || "",
                caption: node.getAttribute("alt") || ""
              });
              return;
            }

            if (tag === "pre") {
              const code = node.querySelector("code");
              pushBlock("codeBlock", code?.innerText || node.innerText || "", {
                language: code?.className || ""
              });
              return;
            }

            if (tag === "blockquote") {
              pushBlock("pullQuote", node.textContent, {
                caption: node.querySelector("cite")?.textContent || ""
              });
              return;
            }

            if (tag === "h1" || tag === "h2") {
              pushBlock("heading", node.textContent);
              return;
            }

            if (tag === "h3" || tag === "h4") {
              pushBlock("subheading", node.textContent);
              return;
            }

            if (tag === "ul" || tag === "ol") {
              Array.from(node.children).forEach(item => pushBlock("listItem", item.textContent));
              return;
            }

            if (tag === "p") {
              pushBlock("paragraph", node.textContent);
              return;
            }

            Array.from(node.children).forEach(walk);
          };

          Array.from(bodyNode?.children || []).forEach(walk);

          return {
            title,
            excerpt,
            byline,
            heroImage:
              document.querySelector('meta[property="og:image"]')?.content ||
              document.querySelector('meta[name="twitter:image"]')?.content ||
              bodyNode?.querySelector("img")?.getAttribute("src") ||
              "",
            bodyText,
            blocksJSON: JSON.stringify(blocks)
          };
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] value, _ in
            guard let self else { return }
            guard let payload = value as? [String: Any] else { return }

            let pageText = ReaderArticleContent.cleaned(payload["bodyText"] as? String)
            guard let pageText, pageText.count > 280 else { return }

            self.readerContent = ReaderArticleContent(
                title: ReaderArticleContent.cleaned(payload["title"] as? String) ?? self.readerContent.title,
                source: self.readerContent.source,
                byline: ReaderArticleContent.cleaned(payload["byline"] as? String) ?? self.readerContent.byline,
                excerpt: ReaderArticleContent.cleaned(payload["excerpt"] as? String) ?? self.readerContent.excerpt,
                heroImageURL: ReaderArticleContent.imageURL(from: payload["heroImage"] as? String) ?? self.readerContent.heroImageURL,
                blocks: ReaderArticleContent.decodeBlocks(from: payload["blocksJSON"] as? String) ?? ReaderArticleContent.blocks(from: pageText),
                bodyText: pageText
            )
        }
    }
}

extension ArticleWebViewStore: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshReaderContentFromPage()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }
}

#if os(macOS)
private struct PlatformWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
private struct PlatformWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

#if os(iOS)
private struct SafariReaderSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
