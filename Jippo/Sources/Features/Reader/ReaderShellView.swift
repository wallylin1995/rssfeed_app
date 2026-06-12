import SwiftUI
import SwiftData

struct ReaderShellView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\FeedRecord.displayOrder)]) private var feeds: [FeedRecord]
    @AppStorage("app.appearance") private var appearanceStorage = AppAppearanceMode.system.rawValue
    @AppStorage("reader.fontScale") private var fontScaleStorage = 1.0
    @AppStorage("reader.width") private var widthStorage = DetailReaderWidth.comfortable.rawValue
    @AppStorage("reader.theme") private var themeStorage = DetailReaderTheme.automatic.rawValue

    init() {}

    var body: some View {
        Group {
#if os(macOS)
            if showsExpandedToday {
                NavigationSplitView {
                    sidebarRoot
                } detail: {
                    ReaderContentColumn(selection: appModel.selectedSidebar, selectedArticleID: selectedArticleID)
                        .modifier(ContentColumnWidthModifier(selection: appModel.selectedSidebar, isExpandedToday: true))
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationSplitView {
                    sidebarRoot
                } content: {
                    ReaderContentColumn(selection: appModel.selectedSidebar, selectedArticleID: selectedArticleID)
                        .modifier(ContentColumnWidthModifier(selection: appModel.selectedSidebar, isExpandedToday: false))
                } detail: {
                    ReaderDetailColumn(selection: appModel.selectedSidebar, selectedArticleID: selectedArticleID)
                }
                .navigationSplitViewStyle(.balanced)
            }
#else
            NavigationSplitView {
                sidebarRoot
            } content: {
                ReaderContentColumn(selection: appModel.selectedSidebar, selectedArticleID: selectedArticleID)
                    .modifier(ContentColumnWidthModifier(selection: appModel.selectedSidebar, isExpandedToday: false))
            } detail: {
                ReaderDetailColumn(selection: appModel.selectedSidebar, selectedArticleID: selectedArticleID)
            }
                .navigationSplitViewStyle(.balanced)
#endif
        }
        .modifier(MacToolbarSearchModifier(searchText: $appModel.articleSearchText))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Appearance", selection: $appearanceStorage) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.symbolName)
                                .tag(mode.rawValue)
                        }
                    }
                } label: {
                    Label("Appearance", systemImage: appearanceMenuSymbol)
                }
                .menuStyle(.borderlessButton)
            }

#if os(macOS)
            if detailToolbarContext.isVisible {
                ToolbarItemGroup(placement: .automatic) {
                    if detailToolbarContext.presentationMode == .original {
                        toolbarIconButton(
                            title: "Back",
                            systemImage: "chevron.backward",
                            isEnabled: detailToolbarContext.canGoBack,
                            action: detailToolbarContext.webBack
                        )

                        toolbarIconButton(
                            title: "Forward",
                            systemImage: "chevron.forward",
                            isEnabled: detailToolbarContext.canGoForward,
                            action: detailToolbarContext.webForward
                        )

                        toolbarIconButton(
                            title: detailToolbarContext.webIsLoading ? "Stop" : "Reload",
                            systemImage: detailToolbarContext.webIsLoading ? "xmark" : "arrow.clockwise",
                            isEnabled: true,
                            action: detailToolbarContext.webReloadOrStop
                        )
                    } else {
                        toolbarIconButton(
                            title: "Previous Story",
                            systemImage: "chevron.up",
                            isEnabled: detailToolbarContext.canGoPrevious,
                            action: detailToolbarContext.goPrevious
                        )

                        toolbarIconButton(
                            title: "Next Story",
                            systemImage: "chevron.down",
                            isEnabled: detailToolbarContext.canGoNext,
                            action: detailToolbarContext.goNext
                        )
                    }

                    toolbarIconButton(
                        title: detailToolbarContext.unread ? "Mark Read" : "Mark Unread",
                        systemImage: detailToolbarContext.unread ? "circlebadge" : "circlebadge.fill",
                        isEnabled: true,
                        action: detailToolbarContext.toggleUnread
                    )

                    toolbarIconButton(
                        title: detailToolbarContext.starred ? "Unstar" : "Star",
                        systemImage: detailToolbarContext.starred ? "star.fill" : "star",
                        isEnabled: true,
                        action: detailToolbarContext.toggleStar
                    )
                }

                ToolbarItem(placement: .automatic) {
                    Picker("Mode", selection: detailPresentationBinding) {
                        ForEach(DetailPresentationMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                ToolbarItemGroup(placement: .automatic) {
                    toolbarIconButton(
                        title: "Summarize",
                        systemImage: "text.alignleft",
                        isEnabled: detailToolbarContext.canRunIntelligenceActions && !detailToolbarContext.intelligenceBusy,
                        action: detailToolbarContext.summarize
                    )

                    toolbarTextButton(
                        title: "Translate to Traditional Chinese",
                        text: "繁",
                        isEnabled: detailToolbarContext.canRunIntelligenceActions && !detailToolbarContext.intelligenceBusy,
                        action: detailToolbarContext.translateTraditionalChinese
                    )

                    toolbarTextButton(
                        title: "Translate to English",
                        text: "EN",
                        isEnabled: detailToolbarContext.canRunIntelligenceActions && !detailToolbarContext.intelligenceBusy,
                        action: detailToolbarContext.translateEnglish
                    )

                    if detailToolbarContext.hasIntelligenceOutput {
                        toolbarIconButton(
                            title: "Clear Intelligence Output",
                            systemImage: "xmark",
                            isEnabled: !detailToolbarContext.intelligenceBusy,
                            action: detailToolbarContext.clearIntelligence
                        )
                    }

                    if detailToolbarContext.intelligenceBusy {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ToolbarItemGroup(placement: .automatic) {
                    if let articleLink = detailToolbarContext.articleLink {
                        ShareLink(item: articleLink) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .help("Share Article")
                    }

                    readerAppearanceMenu
                }
            }
#endif

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await appModel.refreshAll(context: modelContext)
                    }
                } label: {
                    if appModel.isRefreshing {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(appModel.isRefreshing)
            }
        }
        .alert("Refresh Error", isPresented: refreshErrorPresented) {
            Button("OK", role: .cancel) {
                appModel.lastErrorMessage = nil
            }
        } message: {
            Text(appModel.lastErrorMessage ?? "Unknown error")
        }
    }

    private var appearanceMenuSymbol: String {
        (AppAppearanceMode(rawValue: appearanceStorage) ?? .system).symbolName
    }

    private var detailToolbarContext: ReaderDetailToolbarContext {
        appModel.detailToolbarContext
    }

    private var detailPresentationBinding: Binding<DetailPresentationMode> {
        Binding(
            get: { detailToolbarContext.presentationMode },
            set: { detailToolbarContext.setPresentationMode?($0) }
        )
    }

    @ViewBuilder
    private var readerAppearanceMenu: some View {
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
        }
        .help("Reader Appearance")
        .disabled(detailToolbarContext.presentationMode == .original)
    }

    private func toolbarIconButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemImage)
        }
        .help(title)
        .disabled(action == nil || !isEnabled)
    }

    private func toolbarTextButton(
        title: String,
        text: String,
        isEnabled: Bool,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(minWidth: 18)
        }
        .help(title)
        .disabled(action == nil || !isEnabled)
    }

    private var sidebarSelection: Binding<ReaderSidebarSelection> {
        Binding(
            get: { appModel.selectedSidebar },
            set: {
                appModel.selectedSidebar = $0
                appModel.selectedArticleID = nil
            }
        )
    }

    private var showsExpandedToday: Bool {
#if os(macOS)
        appModel.selectedSidebar == .today && appModel.selectedArticleID == nil
#else
        false
#endif
    }

    private var selectedArticleID: Binding<UUID?> {
        Binding(
            get: { appModel.selectedArticleID },
            set: { appModel.selectedArticleID = $0 }
        )
    }

    private var refreshErrorPresented: Binding<Bool> {
        Binding(
            get: { appModel.lastErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    appModel.lastErrorMessage = nil
                }
            }
        )
    }

    private var sidebarRoot: some View {
        sidebarList
            .navigationTitle("Jippo")
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var sidebarList: some View {
#if os(macOS)
        List(selection: sidebarSelection) {
            sidebarSections
        }
        .listStyle(.sidebar)
#else
        List {
            sidebarSections
        }
#endif
    }

    @ViewBuilder
    private var sidebarSections: some View {
        Section("Front Page") {
            sidebarItem(.today, systemImage: "sparkles.rectangle.stack", title: "Today")
            sidebarItem(.saved, systemImage: "bookmark", title: "Saved")
        }

        Section("Feeds") {
            ForEach(feeds) { feed in
                sidebarItem(.feed(feed.uuid)) {
                    FeedSidebarRow(feed: feed)
                }
            }
        }
    }

    @ViewBuilder
    private func sidebarItem(_ selection: ReaderSidebarSelection, systemImage: String, title: String) -> some View {
#if os(macOS)
        Label(title, systemImage: systemImage)
            .tag(selection)
#else
        Button {
            sidebarSelection.wrappedValue = selection
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowBackground(appModel.selectedSidebar == selection ? JippoPalette.panelSoft : Color.clear)
#endif
    }

    @ViewBuilder
    private func sidebarItem<Content: View>(_ selection: ReaderSidebarSelection, @ViewBuilder content: () -> Content) -> some View {
#if os(macOS)
        content()
            .tag(selection)
#else
        Button {
            sidebarSelection.wrappedValue = selection
        } label: {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowBackground(appModel.selectedSidebar == selection ? JippoPalette.panelSoft : Color.clear)
#endif
    }
}

private struct MacToolbarSearchModifier: ViewModifier {
    @Binding var searchText: String

    func body(content: Content) -> some View {
#if os(macOS)
        content.searchable(text: $searchText, prompt: "Search articles")
#else
        content
#endif
    }
}

private struct ContentColumnWidthModifier: ViewModifier {
    let selection: ReaderSidebarSelection
    let isExpandedToday: Bool

    func body(content: Content) -> some View {
#if os(macOS)
        if isExpandedToday {
            content
        } else {
            content
                .navigationSplitViewColumnWidth(
                    selection == .today ? 760 : 420
                )
        }
#else
        content
#endif
    }
}

private struct FeedSidebarRow: View {
    let feed: FeedRecord

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(feed.category.color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(feed.title)
                    .font(.headline)
                Text(feed.category.shortLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReaderContentColumn: View {
    let selection: ReaderSidebarSelection
    @Binding var selectedArticleID: UUID?

    var body: some View {
        switch selection {
        case .today:
            HomeView(selectedArticleID: $selectedArticleID)
        case .saved:
            ArticleListView(kind: .saved, selectedArticleID: $selectedArticleID)
        case .feed(let id):
            ArticleListView(kind: .feed(id), selectedArticleID: $selectedArticleID)
        }
    }
}

private struct ReaderDetailColumn: View {
    @Environment(\.modelContext) private var modelContext
    let selection: ReaderSidebarSelection
    @Binding var selectedArticleID: UUID?

    var body: some View {
        if let article = selectedArticle {
            ZStack(alignment: .topTrailing) {
                StoryDetailView(
                    article: article,
                    canGoPrevious: previousArticle != nil,
                    canGoNext: nextArticle != nil,
                    goToPrevious: { navigate(to: previousArticle) },
                    goToNext: { navigate(to: nextArticle) },
                    toggleStar: { toggleStar(for: article) },
                    toggleUnread: { toggleUnread(for: article) }
                )

                if selection == .today {
                    Button {
                        selectedArticleID = nil
                    } label: {
                        Label("Back to Today", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(JippoPalette.highlight)
                    .padding(20)
                }
            }
        } else if selection == .today {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(JippoPalette.canvas)
        } else {
            ContentUnavailableView(
                "Select a Story",
                systemImage: "newspaper",
                description: Text("Choose a card from the homepage or a story from the feed list to open it here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(JippoPalette.canvas)
        }
    }

    private var selectedArticle: ArticleRecord? {
        guard let selectedArticleID else { return nil }
        var descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate { $0.uuid == selectedArticleID })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private var orderedArticles: [ArticleRecord] {
        let descriptor: FetchDescriptor<ArticleRecord>

        switch selection {
        case .today:
            descriptor = FetchDescriptor(
                sortBy: [
                    SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
                    SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
                ]
            )
        case .saved:
            descriptor = FetchDescriptor(
                predicate: #Predicate<ArticleRecord> { article in
                    article.starred == true
                },
                sortBy: [
                    SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
                    SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
                ]
            )
        case .feed(let id):
            descriptor = FetchDescriptor(
                predicate: #Predicate<ArticleRecord> { article in
                    article.feed?.uuid == id
                },
                sortBy: [
                    SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
                    SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
                ]
            )
        }

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var selectedIndex: Int? {
        guard let selectedArticleID else { return nil }
        return orderedArticles.firstIndex(where: { $0.uuid == selectedArticleID })
    }

    private var previousArticle: ArticleRecord? {
        guard let selectedIndex, selectedIndex > 0 else { return nil }
        return orderedArticles[selectedIndex - 1]
    }

    private var nextArticle: ArticleRecord? {
        guard let selectedIndex, selectedIndex < orderedArticles.count - 1 else { return nil }
        return orderedArticles[selectedIndex + 1]
    }

    private func navigate(to article: ArticleRecord?) {
        guard let article else { return }
        selectedArticleID = article.uuid
        markArticleRead(article)
    }

    private func toggleStar(for article: ArticleRecord) {
        article.starred.toggle()
        try? modelContext.save()
    }

    private func toggleUnread(for article: ArticleRecord) {
        article.unread.toggle()
        try? modelContext.save()
    }

    private func markArticleRead(_ article: ArticleRecord) {
        guard article.unread else { return }
        article.unread = false
        try? modelContext.save()
    }
}

private enum ArticleListKind {
    case feed(UUID)
    case saved
}

private struct ArticleListView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [ArticleRecord]
    let kind: ArticleListKind
    @Binding var selectedArticleID: UUID?

    init(kind: ArticleListKind, selectedArticleID: Binding<UUID?>) {
        self.kind = kind
        _selectedArticleID = selectedArticleID

        switch kind {
        case .feed(let feedID):
            _articles = Query(
                filter: #Predicate<ArticleRecord> { article in
                    article.feed?.uuid == feedID
                },
                sort: [
                    SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
                    SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
                ]
            )
        case .saved:
            _articles = Query(
                filter: #Predicate<ArticleRecord> { article in
                    article.starred == true
                },
                sort: [
                    SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
                    SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
                ]
            )
        }
    }

    var body: some View {
        articleList
            .scrollContentBackground(.hidden)
            .background(JippoPalette.canvas)
            .navigationTitle(title)
    }

    private var title: String {
        switch kind {
        case .feed(let feedID):
            feedTitle(for: feedID) ?? "Feed Stories"
        case .saved:
            "Saved Stories"
        }
    }

    @ViewBuilder
    private var articleList: some View {
#if os(macOS)
        List(selection: $selectedArticleID) {
            articleRows
        }
        .listStyle(.plain)
#else
        List {
            articleRows
        }
#endif
    }

    @ViewBuilder
    private var articleRows: some View {
        if filteredArticles.isEmpty {
            ContentUnavailableView(
                appModel.articleSearchText.isEmpty ? "No Articles" : "No Results",
                systemImage: appModel.articleSearchText.isEmpty ? "newspaper" : "magnifyingglass",
                description: Text(appModel.articleSearchText.isEmpty ? "Stories from this feed will appear here." : "Try a different search term.")
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(filteredArticles) { article in
                articleRow(article)
            }
        }
    }

    @ViewBuilder
    private func articleRow(_ article: ArticleRecord) -> some View {
#if os(macOS)
        articleRowContent(article)
            .tag(article.uuid)
            .contextMenu {
                articleContextMenu(article)
            }
#else
        Button {
            selectArticle(article)
        } label: {
            articleRowContent(article)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowBackground(selectedArticleID == article.uuid ? JippoPalette.panelSoft : Color.clear)
        .contextMenu {
            articleContextMenu(article)
        }
#endif
    }

    private func articleRowContent(_ article: ArticleRecord) -> some View {
        ArticleListRow(
            article: article,
            isSelected: selectedArticleID == article.uuid,
            openArticle: { selectArticle(article) },
            toggleStar: { toggleStar(for: article) }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var filteredArticles: [ArticleRecord] {
        guard !appModel.articleSearchText.isEmpty else { return articles }

        let needle = appModel.articleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return articles }

        return articles.filter { article in
            [article.title, article.sourceTitle, article.displaySummary, article.displayByline]
                .joined(separator: "\n")
                .lowercased()
                .contains(needle)
        }
    }

    private func selectArticle(_ article: ArticleRecord) {
        selectedArticleID = article.uuid
        markArticleRead(article)
    }

    private func toggleStar(for article: ArticleRecord) {
        article.starred.toggle()
        try? modelContext.save()
    }

    private func toggleUnread(for article: ArticleRecord) {
        article.unread.toggle()
        try? modelContext.save()
    }

    private func markArticleRead(_ article: ArticleRecord) {
        guard article.unread else { return }
        article.unread = false
        try? modelContext.save()
    }

    private func feedTitle(for feedID: UUID) -> String? {
        var descriptor = FetchDescriptor<FeedRecord>(predicate: #Predicate { $0.uuid == feedID })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.title
    }

    @ViewBuilder
    private func articleContextMenu(_ article: ArticleRecord) -> some View {
        Button(article.unread ? "Mark as Read" : "Mark as Unread") {
            toggleUnread(for: article)
        }

        Button(article.starred ? "Remove Star" : "Star") {
            toggleStar(for: article)
        }
    }
}

private struct ArticleListRow: View {
    let article: ArticleRecord
    let isSelected: Bool
    let openArticle: () -> Void
    let toggleStar: () -> Void

    var body: some View {
        Button(action: openArticle) {
            HStack(alignment: .top, spacing: 14) {
                articleThumbnail

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        feedBadge

                        if article.unread {
                            Circle()
                                .fill(JippoPalette.highlight)
                                .frame(width: 8, height: 8)
                        }

                        Spacer(minLength: 8)

                        Text(article.displayDateText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(article.title)
                        .font(.system(size: 17, weight: article.unread ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    Text(article.displaySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(article.displayByline)
                            .lineLimit(1)

                        if article.starred {
                            Image(systemName: "star.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                }

                Button(action: toggleStar) {
                    Image(systemName: article.starred ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(article.starred ? .yellow : .secondary)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(isSelected ? 0.08 : 0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var articleThumbnail: some View {
        Group {
            if let imageLink = article.imageLink {
                AsyncImage(url: imageLink) { phase in
                    switch phase {
                    case .empty:
                        thumbnailPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    article.feed?.category.color.opacity(0.85) ?? JippoPalette.highlight.opacity(0.85),
                    JippoPalette.panelSoft
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "newspaper.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var feedBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(article.feed?.category.color ?? JippoPalette.highlight)
                .frame(width: 7, height: 7)

            Text(article.sourceTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(article.feed?.category.color ?? JippoPalette.highlight)
                .lineLimit(1)
        }
    }

    private var rowBackground: Color {
        isSelected ? JippoPalette.panelSoft.opacity(0.9) : JippoPalette.panel.opacity(0.55)
    }

    private var borderColor: Color {
        isSelected ? JippoPalette.highlight.opacity(0.32) : .white.opacity(0.05)
    }
}

#Preview {
    ReaderShellView()
        .environmentObject(AppModel())
        .modelContainer(for: [
            FeedRecord.self,
            ArticleRecord.self,
            ArticleContentRecord.self,
            HomepagePlanRecord.self,
            HomepageSectionRecord.self,
            HomepagePlacementRecord.self
        ], inMemory: true)
        .preferredColorScheme(.dark)
}
