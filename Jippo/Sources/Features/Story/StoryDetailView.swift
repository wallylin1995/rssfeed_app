import SwiftUI
import WebKit

struct StoryDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    let article: ArticleRecord
    let canGoPrevious: Bool
    let canGoNext: Bool
    let goToPrevious: () -> Void
    let goToNext: () -> Void
    let toggleStar: () -> Void
    let toggleUnread: () -> Void

    @StateObject private var intelligence: ArticleIntelligenceViewModel
    @StateObject private var webStore: ArticleWebViewStore
    @State private var presentationMode: DetailPresentationMode = .rss
    @State private var showingReaderSuggestion = false
    @State private var dismissedReaderSuggestion = false
    @AppStorage("reader.fontScale") private var fontScaleStorage = 1.0
    @AppStorage("reader.width") private var widthStorage = DetailReaderWidth.comfortable.rawValue
    @AppStorage("reader.theme") private var themeStorage = DetailReaderTheme.automatic.rawValue

    init(
        article: ArticleRecord,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        goToPrevious: @escaping () -> Void = {},
        goToNext: @escaping () -> Void = {},
        toggleStar: @escaping () -> Void = {},
        toggleUnread: @escaping () -> Void = {}
    ) {
        self.article = article
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.goToPrevious = goToPrevious
        self.goToNext = goToNext
        self.toggleStar = toggleStar
        self.toggleUnread = toggleUnread
        _intelligence = StateObject(wrappedValue: ArticleIntelligenceViewModel(article: article))
        _webStore = StateObject(
            wrappedValue: ArticleWebViewStore(
                articleURL: article.articleLink,
                fallbackContent: ReaderArticleContent.from(article: article)
            )
        )
    }

    var body: some View {
        Group {
            if presentationMode == .original {
                originalColumn
            } else {
                ScrollView {
                    readableColumn
                }
            }
        }
        .background(readerTheme.canvasColor.ignoresSafeArea())
        .navigationTitle(article.sourceTitle)
        .jippoTitleDisplayMode(.inline)
        .task(id: article.uuid) {
            showingReaderSuggestion = false
            dismissedReaderSuggestion = false
            presentationMode = .rss
            webStore.presentArticle(url: article.articleLink, fallbackContent: rssContent)
            syncIntelligenceSource()
            evaluateReaderSuggestion()
            syncToolbarContext()
        }
        .onChange(of: presentationMode) { _, _ in
            syncIntelligenceSource()
            evaluateReaderSuggestion()
            syncToolbarContext()
        }
        .onChange(of: webReaderFingerprint) { _, _ in
            syncIntelligenceSource()
            evaluateReaderSuggestion()
            syncToolbarContext()
        }
        .onChange(of: toolbarFingerprint) { _, _ in
            syncToolbarContext()
        }
        .onDisappear {
            appModel.clearDetailToolbarContext(for: article.uuid)
        }
        .confirmationDialog(
            "Open Reader Mode?",
            isPresented: $showingReaderSuggestion,
            titleVisibility: .visible
        ) {
            Button("Open Reader") {
                presentationMode = .reader
                dismissedReaderSuggestion = true
            }

            Button("Stay on Original") {
                dismissedReaderSuggestion = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This feed looks abbreviated. Jippo can switch the webpage into a cleaner reading view, like Safari Reader.")
        }
    }

    private var readableColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
#if !os(macOS)
            readerToolbar
#endif
            if intelligencePanelVisible {
                intelligencePanel
            }
            readableContent
        }
        .padding(20)
        .frame(maxWidth: min(readerWidth.maxWidth, 920))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var originalColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
#if !os(macOS)
            readerToolbar
#endif
            if intelligencePanelVisible {
                intelligencePanel
            }
            originalContent
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var readableContent: some View {
        let content = activeReadableContent

        return VStack(alignment: .leading, spacing: 22) {
            if presentationMode == .reader && webStore.isLoading && !readerContentReady {
                readerLoadingCard
            }

            if let heroImage = content.heroImageURL ?? article.imageLink {
                AsyncImage(url: heroImage) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 280)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(JippoPalette.panelSoft)
                            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320)
                    @unknown default:
                        EmptyView()
                    }
                }
                .cardChrome(radius: 34)
            }

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Text(content.source.uppercased())
                        Text(modeHeadline)
                    }
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(readerTheme.accentColor)

                    Text(content.title)
                        .font(.system(size: 32 * fontScale, weight: .bold, design: .rounded))
                        .foregroundStyle(readerTheme.primaryTextColor)

                    HStack(spacing: 10) {
                        Text(article.displayDateText)
                        if let byline = content.byline, !byline.isEmpty {
                            Text("•")
                            Text(byline)
                        }
                        if let topicLabel = article.topicLabel {
                            Text("•")
                            Text(topicLabel)
                        }
                        if let readingTime = content.readingTime {
                            Text("•")
                            Text(readingTime)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(readerTheme.secondaryTextColor)

                    if let excerpt = content.excerpt, !excerpt.isEmpty {
                        Text(excerpt)
                            .font(.system(size: 20 * fontScale, weight: .medium, design: .serif))
                            .foregroundStyle(readerTheme.secondaryTextColor)
                    }

                    if presentationMode == .rss && rssLooksTruncated, article.articleLink != nil {
                        abridgedNotice
                    }

                    Divider()
                        .overlay(readerTheme.secondaryTextColor.opacity(0.18))

                    if content.blocks.isEmpty {
                        Text(content.bodyText)
                            .font(.system(size: 18 * fontScale, weight: .regular, design: .serif))
                            .lineSpacing(7 * fontScale)
                            .foregroundStyle(readerTheme.primaryTextColor)
                            .textSelection(.enabled)
                    } else {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(Array(content.blocks.enumerated()), id: \.offset) { _, block in
                                readableBlockView(block)
                            }
                        }
                    }
                }
                .padding(24)
                .background(readerTheme.articleSurfaceColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(readerTheme.borderColor, lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var originalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
#if !os(macOS)
            HStack(spacing: 10) {
                headerIconButton(title: "Back", systemImage: "chevron.backward", action: webStore.goBack)
                    .disabled(!webStore.canGoBack)

                headerIconButton(title: "Forward", systemImage: "chevron.forward", action: webStore.goForward)
                    .disabled(!webStore.canGoForward)

                headerIconButton(
                    title: webStore.isLoading ? "Stop" : "Reload",
                    systemImage: webStore.isLoading ? "xmark" : "arrow.clockwise",
                    action: webStore.isLoading ? webStore.stopLoading : webStore.reload
                )

                browserAddressBar
            }
#endif

            if browserShowsLoadingStrip {
                browserLoadingStrip
            }

            InlinePlatformWebView(webView: webStore.webView)
                .frame(minHeight: 760, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(readerTheme.borderColor, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
        .padding(18)
        .background(readerTheme.articleSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var readerToolbar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.sourceTitle.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(readerTheme.accentColor)

                HStack(spacing: 8) {
                    Text(article.displayDateText)
                    Text("•")
                    Text(article.displayByline)
                    if let topicLabel = article.topicLabel {
                        Text("•")
                        Text(topicLabel)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(readerTheme.secondaryTextColor)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                headerIconButton(title: "Previous", systemImage: "chevron.up", action: goToPrevious)
                    .disabled(!canGoPrevious)

                headerIconButton(title: "Next", systemImage: "chevron.down", action: goToNext)
                    .disabled(!canGoNext)

                headerIconButton(
                    title: article.unread ? "Mark Read" : "Mark Unread",
                    systemImage: article.unread ? "circlebadge" : "circlebadge.fill",
                    action: toggleUnread
                )

                headerIconButton(
                    title: article.starred ? "Unstar" : "Star",
                    systemImage: article.starred ? "star.fill" : "star",
                    action: toggleStar
                )
            }

            Picker("Presentation Mode", selection: $presentationMode) {
                ForEach(DetailPresentationMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)

            HStack(spacing: 8) {
                intelligenceToolbarGroup

                if let articleLink = article.articleLink {
                    ShareLink(item: articleLink) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .help("Share Article")
                }

                Menu {
                    Section("Text Size") {
                        Button("Smaller") {
                            fontScaleStorage = max(0.88, fontScaleStorage - 0.08)
                        }
                        Button("Larger") {
                            fontScaleStorage = min(1.4, fontScaleStorage + 0.08)
                        }
                    }

                    Section("Line Width") {
                        ForEach(DetailReaderWidth.allCases) { width in
                            Button(width.label) {
                                widthStorage = width.rawValue
                            }
                        }
                    }

                    Section("Theme") {
                        ForEach(DetailReaderTheme.allCases) { theme in
                            Button(theme.label) {
                                themeStorage = theme.rawValue
                            }
                        }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 14, height: 14)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.bordered)
                .help("Reader Appearance")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(readerTheme.toolbarSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func headerIconButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help(title)
    }

    private var intelligenceToolbarGroup: some View {
        HStack(spacing: 8) {
            toolbarBadgeButton(
                title: "Summarize",
                isActive: intelligence.summary != nil && intelligence.translation == nil,
                action: {
                    Task { await intelligence.summarize() }
                }
            ) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 14, height: 14)
            }
            .disabled(!canRunIntelligenceActions || intelligence.isBusy)

            toolbarBadgeButton(
                title: "Translate to Traditional Chinese",
                isActive: activeTranslationIsTraditionalChinese,
                action: {
                    Task { await intelligence.translateToTraditionalChinese() }
                }
            ) {
                Text("繁")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(minWidth: 16)
            }
            .disabled(!canRunIntelligenceActions || intelligence.isBusy)

            toolbarBadgeButton(
                title: "Translate to English",
                isActive: activeTranslationIsEnglish,
                action: {
                    Task { await intelligence.translateToEnglish() }
                }
            ) {
                Text("EN")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .frame(minWidth: 16)
            }
            .disabled(!canRunIntelligenceActions || intelligence.isBusy)

            if intelligencePanelVisible {
                toolbarBadgeButton(
                    title: "Clear Intelligence Output",
                    isActive: false,
                    action: {
                        intelligence.clearOutputs()
                    }
                ) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 14, height: 14)
                }
            }

            if intelligence.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(readerTheme.accentColor)
                    .frame(width: 22, height: 22)
            }
        }
    }

    private func toolbarBadgeButton<Label: View>(
        title: String,
        isActive: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(isActive ? Color.white : readerTheme.primaryTextColor)
                .frame(minWidth: 18, minHeight: 18)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Group {
                if isActive {
                    Capsule()
                        .fill(readerTheme.accentColor)
                } else {
                    Capsule()
                        .fill(readerTheme.controlSurfaceColor)
                }
            }
        )
        .overlay {
            Capsule()
                .stroke(isActive ? readerTheme.accentColor : readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .help(title)
    }

    private func readableBlockView(_ block: ReaderBlock) -> some View {
        Group {
            switch block.kind {
            case .heading:
                Text(block.text)
                    .font(.system(size: 28 * fontScale, weight: .bold, design: .rounded))
                    .foregroundStyle(readerTheme.primaryTextColor)
            case .subheading:
                Text(block.text)
                    .font(.system(size: 23 * fontScale, weight: .semibold, design: .rounded))
                    .foregroundStyle(readerTheme.primaryTextColor)
            case .paragraph:
                Text(block.text)
                    .font(.system(size: 18 * fontScale, weight: .regular, design: .serif))
                    .lineSpacing(7 * fontScale)
                    .foregroundStyle(readerTheme.primaryTextColor)
                    .textSelection(.enabled)
            case .pullQuote:
                VStack(alignment: .leading, spacing: 8) {
                    Text(block.text)
                        .font(.system(size: 24 * fontScale, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(readerTheme.primaryTextColor)

                    if let caption = block.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(readerTheme.secondaryTextColor)
                    }
                }
                .padding(.leading, 18)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(readerTheme.accentColor)
                        .frame(width: 4)
                }
            case .listItem:
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(readerTheme.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 10)

                    Text(block.text)
                        .font(.system(size: 18 * fontScale, weight: .regular, design: .serif))
                        .lineSpacing(7 * fontScale)
                        .foregroundStyle(readerTheme.primaryTextColor)
                }
            case .image:
                VStack(alignment: .leading, spacing: 10) {
                    if let url = block.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 220)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(readerTheme.controlSurfaceColor)
                                    .frame(maxWidth: .infinity, minHeight: 220)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if let caption = block.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(readerTheme.secondaryTextColor)
                    }
                }
            case .imageGallery:
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(block.mediaItems.enumerated()), id: \.offset) { _, item in
                        if let url = item.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 180)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(readerTheme.controlSurfaceColor)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            case .caption:
                Text(block.text)
                    .font(.caption)
                    .foregroundStyle(readerTheme.secondaryTextColor)
            case .codeBlock:
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(block.text)
                        .font(.system(size: 14 * fontScale, weight: .regular, design: .monospaced))
                        .foregroundStyle(readerTheme.primaryTextColor)
                        .padding(18)
                }
                .background(readerTheme.controlSurfaceColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var abridgedNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.page.badge.magnifyingglass")
                .foregroundStyle(readerTheme.accentColor)

            VStack(alignment: .leading, spacing: 8) {
                Text("This feed looks shortened.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(readerTheme.primaryTextColor)

                Text("Open the webpage if you want the full article, then Jippo can offer a cleaner Reader mode.")
                    .font(.caption)
                    .foregroundStyle(readerTheme.secondaryTextColor)

                Button("Open Web View") {
                    presentationMode = .original
                }
                .buttonStyle(.borderedProminent)
                .tint(readerTheme.accentColor)
            }
        }
        .padding(16)
        .background(readerTheme.toolbarSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var readerLoadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preparing web reader")
                .font(.headline.weight(.semibold))
                .foregroundStyle(readerTheme.primaryTextColor)

            Text("Jippo is extracting the article text from the webpage so you can read it without page clutter.")
                .font(.subheadline)
                .foregroundStyle(readerTheme.secondaryTextColor)

            ProgressView(value: webStore.estimatedProgress)
                .progressViewStyle(.linear)
                .tint(readerTheme.accentColor)
        }
        .padding(18)
        .background(readerTheme.toolbarSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var browserAddressBar: some View {
        HStack(spacing: 12) {
            Image(systemName: browserLocationSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(webStore.isLoading ? readerTheme.accentColor : readerTheme.secondaryTextColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(browserTitleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(readerTheme.primaryTextColor)
                    .lineLimit(1)

                Text(browserURLText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(readerTheme.secondaryTextColor)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Text(browserStatusText)
                .font(.caption.weight(.bold))
                .foregroundStyle(webStore.isLoading ? readerTheme.accentColor : readerTheme.secondaryTextColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(readerTheme.controlSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private var browserLoadingStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Loading original article")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(readerTheme.primaryTextColor)

                Spacer()

                Text("\(Int(webStore.estimatedProgress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(readerTheme.secondaryTextColor)
            }

            ProgressView(value: webStore.estimatedProgress)
                .progressViewStyle(.linear)
                .tint(readerTheme.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(readerTheme.toolbarSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var intelligencePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Label("Apple Intelligence", systemImage: "apple.intelligence")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(readerTheme.primaryTextColor)

                Spacer()

                if intelligence.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorMessage = intelligence.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(readerTheme.secondaryTextColor)
            }

            if intelligence.isSummarizing {
                intelligenceCard(
                    title: "Generating Summary",
                    systemImage: "sparkles",
                    body: "Jippo is distilling the current \(modeHeadline.lowercased()) content into a shorter editorial brief."
                )
            }

            if intelligence.isTranslating {
                intelligenceCard(
                    title: "Translating",
                    systemImage: "globe",
                    body: "Jippo is translating the current article text from the active reading source."
                )
            }

            if let summary = intelligence.summary, !summary.isEmpty {
                intelligenceCard(title: "Summary", systemImage: "sparkles", body: summary)
            }

            if let translation = intelligence.translation {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Translation · \(translation.targetLanguageLabel)", systemImage: "text.bubble")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(readerTheme.accentColor)

                    Text(translation.translatedTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(readerTheme.primaryTextColor)

                    if let translatedSummary = translation.translatedSummary, !translatedSummary.isEmpty {
                        Text(translatedSummary)
                            .font(.body)
                            .foregroundStyle(readerTheme.secondaryTextColor)
                    }

                    Text(translation.translatedBody)
                        .font(.body)
                        .foregroundStyle(readerTheme.primaryTextColor)
                        .textSelection(.enabled)
                }
                .padding(18)
                .background(readerTheme.toolbarSurfaceColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(readerTheme.borderColor, lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(18)
        .background(readerTheme.toolbarSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func intelligenceCard(title: String, systemImage: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(readerTheme.accentColor)

            Text(body)
                .font(.body)
                .foregroundStyle(readerTheme.primaryTextColor)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(readerTheme.toolbarSurfaceColor)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(readerTheme.borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var fontScale: CGFloat {
        CGFloat(fontScaleStorage)
    }

    private var activeReadableContent: ReaderArticleContent {
        presentationMode == .reader ? webStore.readerContent : rssContent
    }

    private var rssContent: ReaderArticleContent {
        ReaderArticleContent.from(article: article)
    }

    private var readerWidth: DetailReaderWidth {
        DetailReaderWidth(rawValue: widthStorage) ?? .comfortable
    }

    private var readerTheme: DetailReaderTheme {
        let storedTheme = DetailReaderTheme(rawValue: themeStorage) ?? .automatic
        if storedTheme == .graphite && colorScheme == .light {
            return .paper
        }
        return storedTheme.resolved(for: colorScheme)
    }

    private var browserTitleText: String {
        let candidate = webStore.pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return candidate.isEmpty ? article.title : candidate
    }

    private var browserURLText: String {
        let url = webStore.currentURL ?? article.articleLink
        return url?.absoluteString ?? "No source URL available"
    }

    private var browserStatusText: String {
        if webStore.isLoading {
            return webStore.estimatedProgress > 0 ? "Fetching" : "Connecting"
        }

        if let host = (webStore.currentURL ?? article.articleLink)?.host() {
            return host
        }

        return "Ready"
    }

    private var browserLocationSymbol: String {
        guard let scheme = (webStore.currentURL ?? article.articleLink)?.scheme?.lowercased() else {
            return "globe"
        }

        return scheme == "https" ? "lock.fill" : "globe"
    }

    private var browserShowsLoadingStrip: Bool {
        webStore.isLoading || (webStore.estimatedProgress > 0 && webStore.estimatedProgress < 1)
    }

    private var modeHeadline: String {
        switch presentationMode {
        case .rss: "RSS VIEW"
        case .reader: "WEB READER"
        case .original: "ORIGINAL"
        }
    }

    private var rssLooksTruncated: Bool {
        let count = rssContent.bodyText.count
        return count < 1400 || rssContent.blocks.count < 5
    }

    private var readerContentReady: Bool {
        webStore.readerContent.bodyText.count > 300
    }

    private var webReaderFingerprint: String {
        [
            webStore.readerContent.title,
            webStore.readerContent.excerpt ?? "",
            webStore.readerContent.bodyText
        ].joined(separator: "\n")
    }

    private var shouldOfferReaderUpgrade: Bool {
        guard presentationMode == .original else { return false }
        guard rssLooksTruncated else { return false }
        guard readerContentReady else { return false }

        let rssLength = max(rssContent.bodyText.count, 1)
        let webLength = webStore.readerContent.bodyText.count
        return webLength > max(1400, rssLength + 500) && webLength > Int(Double(rssLength) * 1.25)
    }

    private func syncIntelligenceSource() {
        guard presentationMode != .original else { return }
        intelligence.updateSnapshot(ArticleSnapshot(content: activeReadableContent))
    }

    private func evaluateReaderSuggestion() {
        guard shouldOfferReaderUpgrade else { return }
        guard !dismissedReaderSuggestion else { return }
        showingReaderSuggestion = true
    }

    private func syncToolbarContext() {
#if os(macOS)
        appModel.setDetailToolbarContext(
            ReaderDetailToolbarContext(
                articleID: article.uuid,
                articleLink: article.articleLink,
                presentationMode: presentationMode,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                unread: article.unread,
                starred: article.starred,
                canRunIntelligenceActions: canRunIntelligenceActions,
                intelligenceBusy: intelligence.isBusy,
                hasIntelligenceOutput: intelligencePanelVisible,
                canGoBack: webStore.canGoBack,
                canGoForward: webStore.canGoForward,
                webIsLoading: webStore.isLoading,
                goPrevious: goToPrevious,
                goNext: goToNext,
                toggleUnread: toggleUnread,
                toggleStar: toggleStar,
                setPresentationMode: { presentationMode = $0 },
                summarize: {
                    Task { await intelligence.summarize() }
                },
                translateTraditionalChinese: {
                    Task { await intelligence.translateToTraditionalChinese() }
                },
                translateEnglish: {
                    Task { await intelligence.translateToEnglish() }
                },
                clearIntelligence: {
                    intelligence.clearOutputs()
                },
                webBack: webStore.goBack,
                webForward: webStore.goForward,
                webReloadOrStop: webStore.isLoading ? webStore.stopLoading : webStore.reload
            )
        )
#endif
    }

    private var intelligencePanelVisible: Bool {
        intelligence.isBusy || intelligence.hasOutput || intelligence.errorMessage != nil
    }

    private var canRunIntelligenceActions: Bool {
        guard presentationMode != .original else { return false }
        return !activeReadableContent.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeTranslationIsTraditionalChinese: Bool {
        guard let label = intelligence.translation?.targetLanguageLabel.lowercased() else { return false }
        return label.contains("traditional") || label.contains("繁")
    }

    private var activeTranslationIsEnglish: Bool {
        guard let label = intelligence.translation?.targetLanguageLabel.lowercased() else { return false }
        return label == "english" || label.contains("english")
    }

    private var toolbarFingerprint: String {
        [
            article.uuid.uuidString,
            presentationMode.rawValue,
            article.unread.description,
            article.starred.description,
            canGoPrevious.description,
            canGoNext.description,
            canRunIntelligenceActions.description,
            intelligence.isBusy.description,
            intelligencePanelVisible.description,
            webStore.canGoBack.description,
            webStore.canGoForward.description,
            webStore.isLoading.description,
            webStore.currentURL?.absoluteString ?? ""
        ].joined(separator: "|")
    }
}

private extension DetailReaderTheme {
    func resolved(for colorScheme: ColorScheme) -> DetailReaderTheme {
        switch self {
        case .automatic:
            colorScheme == .dark ? .graphite : .paper
        case .graphite, .paper, .sepia:
            self
        }
    }

    var canvasColor: Color {
        switch self {
        case .automatic:
            Color.clear
        case .graphite: Color(red: 0.09, green: 0.10, blue: 0.12)
        case .paper: Color(red: 0.93, green: 0.92, blue: 0.89)
        case .sepia: Color(red: 0.94, green: 0.89, blue: 0.80)
        }
    }

    var articleSurfaceColor: Color {
        switch self {
        case .automatic:
            Color.clear
        case .graphite: Color(red: 0.15, green: 0.16, blue: 0.19)
        case .paper: Color.white.opacity(0.82)
        case .sepia: Color(red: 0.97, green: 0.92, blue: 0.84)
        }
    }

    var toolbarSurfaceColor: Color {
        switch self {
        case .automatic:
            Color.clear
        case .graphite: Color(red: 0.13, green: 0.14, blue: 0.17).opacity(0.96)
        case .paper: Color.white.opacity(0.88)
        case .sepia: Color(red: 0.95, green: 0.90, blue: 0.82)
        }
    }

    var controlSurfaceColor: Color {
        switch self {
        case .automatic:
            Color.clear
        case .graphite: Color.white.opacity(0.08)
        case .paper, .sepia: .black.opacity(0.05)
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .automatic:
            .primary
        case .graphite: .white
        case .paper, .sepia: Color.black.opacity(0.84)
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .automatic:
            .secondary
        case .graphite: .white.opacity(0.7)
        case .paper, .sepia: Color.black.opacity(0.55)
        }
    }

    var accentColor: Color {
        switch self {
        case .automatic:
            JippoPalette.highlight
        case .graphite: JippoPalette.highlight
        case .paper: Color(red: 0.70, green: 0.26, blue: 0.34)
        case .sepia: Color(red: 0.66, green: 0.36, blue: 0.20)
        }
    }

    var borderColor: Color {
        switch self {
        case .automatic:
            .clear
        case .graphite: .white.opacity(0.11)
        case .paper, .sepia: .black.opacity(0.08)
        }
    }
}

#if os(macOS)
private struct InlinePlatformWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
private struct InlinePlatformWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

struct StoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let feed = FeedRecord(feedURL: "https://example.com", title: "Preview Feed", categoryKey: FeedCategory.world.rawValue)
        let article = ArticleRecord(title: "Preview Story", link: "https://example.com/story", sourceTitle: "Preview Feed", feed: feed)
        article.content = ArticleContentRecord(summary: "Summary", text: "Body text", html: "<p>Body text</p>", article: article)

        return NavigationStack {
            StoryDetailView(article: article)
                .preferredColorScheme(.dark)
        }
    }
}
