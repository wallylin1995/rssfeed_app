import SwiftUI
import WebKit
import Combine
#if os(iOS)
import SafariServices
#endif

struct EmbeddedArticleBrowserView: View {
    let article: ArticleRecord

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: ArticleWebViewStore
    @State private var mode: ArticlePresentationMode = .reader
    @State private var preferences = ReaderPreferences()
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
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch mode {
                case .web:
                    PlatformWebView(webView: store.webView)
                        .background(preferences.theme.canvasColor)
                case .reader:
                    ReaderModeView(content: store.readerContent, preferences: preferences)
                        .background(preferences.theme.canvasColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                floatingToolbar

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
        .background(preferences.theme.canvasColor.ignoresSafeArea())
        #if os(iOS)
        .sheet(isPresented: $showingReaderSheet) {
            if let url = article.articleLink {
                SafariReaderSheet(url: url)
            }
        }
        #endif
    }

    private var floatingToolbar: some View {
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
                .frame(width: 196)
            }
            .glassPanel(cornerRadius: 22)

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
                .glassPanel(cornerRadius: 22)
            } else {
                readerPreferencesToolbar
            }

            Spacer(minLength: 0)

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

            #if os(iOS)
            if article.articleLink != nil {
                Button("Safari Reader") {
                    showingReaderSheet = true
                }
                .buttonStyle(.glassProminentOrFallback(tint: JippoPalette.highlight))
            }
            #endif
        }
    }

    private var readerPreferencesToolbar: some View {
        HStack(spacing: 10) {
            preferenceChip(label: "A-", action: { preferences.fontScale = max(0.88, preferences.fontScale - 0.08) })
            preferenceChip(label: "A+", action: { preferences.fontScale = min(1.4, preferences.fontScale + 0.08) })

            Picker("Width", selection: $preferences.width) {
                ForEach(ReaderWidth.allCases) { width in
                    Text(width.shortLabel).tag(width)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Picker("Theme", selection: $preferences.theme) {
                ForEach(ReaderTheme.allCases) { theme in
                    Text(theme.shortLabel).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
        .glassPanel(cornerRadius: 22)
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
        case .graphite: JippoPalette.canvas
        case .paper: Color(red: 0.93, green: 0.92, blue: 0.89)
        case .sepia: Color(red: 0.94, green: 0.89, blue: 0.80)
        }
    }

    var articleSurfaceColor: Color {
        switch self {
        case .graphite: Color.white.opacity(0.03)
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
        case .graphite: Color.white.opacity(0.06)
        case .paper: Color.black.opacity(0.05)
        case .sepia: Color.black.opacity(0.06)
        }
    }
}

private struct ReaderModeView: View {
    let content: ReaderArticleContent
    let preferences: ReaderPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
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
                        ReaderBlockView(block: block, preferences: preferences)
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
        .scrollContentBackground(.hidden)
        .background(preferences.theme.canvasColor)
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
        let summary = cleaned(article.content?.summary)
        let htmlText = cleaned(HTMLContentExtractor.plainText(from: article.content?.html ?? ""))
        let body = cleaned(article.content?.text) ?? htmlText ?? summary ?? ""

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
            .map { ReaderBlock(kind: .paragraph, text: $0, imageURL: nil, caption: nil, language: nil) }
    }

    static func decodeBlocks(from json: String?) -> [ReaderBlock]? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode([ReaderBlockPayload].self, from: data) else { return nil }

        let blocks = payload.compactMap { item -> ReaderBlock? in
            guard let kind = ReaderBlock.Kind(rawValue: item.kind) else { return nil }
            let text = cleaned(item.text) ?? ""
            let caption = cleaned(item.caption)
            let imageURL = imageURL(from: item.imageURL)
            let language = cleaned(item.language)

            if kind != .image && kind != .caption && kind != .codeBlock && text.isEmpty {
                return nil
            }

            if kind == .image && imageURL == nil {
                return nil
            }

            return ReaderBlock(
                kind: kind,
                text: text,
                imageURL: imageURL,
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
    var caption: String?
    var language: String?

    enum Kind: String {
        case heading
        case subheading
        case paragraph
        case pullQuote
        case listItem
        case image
        case caption
        case codeBlock
    }
}

private struct ReaderBlockPayload: Decodable {
    let kind: String
    let text: String
    let imageURL: String?
    let caption: String?
    let language: String?
}

private struct ReaderBlockView: View {
    let block: ReaderBlock
    let preferences: ReaderPreferences

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
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                if let caption = block.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(preferences.theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
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
}

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
                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
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
    @Published var readerContent: ReaderArticleContent

    private let articleURL: URL?
    private var cancellables: Set<AnyCancellable> = []

    init(articleURL: URL?, fallbackContent: ReaderArticleContent) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        self.articleURL = articleURL
        self.readerContent = fallbackContent
        super.init()

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        observeWebView()

        if let articleURL {
            load(url: articleURL)
        } else {
            isLoading = false
        }
    }

    func load(url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        webView.load(request)
    }

    func reload() {
        webView.reload()
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

            if (cleaned || extra.imageURL) {
              blocks.push({ kind, text: cleaned, ...extra });
            }
          };

          root.querySelectorAll("script, style, noscript").forEach(node => node.remove());

          const walk = node => {
            if (!node || node.nodeType !== Node.ELEMENT_NODE) return;
            const tag = node.tagName.toLowerCase();

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
            if (cleaned || extra.imageURL) {
              blocks.push({ kind, text: cleaned, ...extra });
            }
          };

          const walk = node => {
            if (!node || node.nodeType !== Node.ELEMENT_NODE) return;
            const tag = node.tagName.toLowerCase();

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
