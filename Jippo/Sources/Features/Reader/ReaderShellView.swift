import SwiftUI
import SwiftData

struct ReaderShellView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\FeedRecord.displayOrder)]) private var feeds: [FeedRecord]
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarList
            .scrollContentBackground(.hidden)
            .background(JippoPalette.canvas)
            .navigationTitle("Jippo")
        } content: {
            ReaderContentColumn(selection: appModel.selectedSidebar, selectedArticleID: selectedArticleID)
                .modifier(ContentColumnWidthModifier(selection: appModel.selectedSidebar))
        } detail: {
            ReaderDetailColumn(selection: appModel.selectedSidebar, selectedArticleID: appModel.selectedArticleID)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
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
        .onAppear {
            syncColumnVisibility()
        }
        .onChange(of: appModel.selectedSidebar) { _, _ in
            syncColumnVisibility()
        }
        .onChange(of: appModel.selectedArticleID) { _, _ in
            syncColumnVisibility()
        }
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

    private func syncColumnVisibility() {
#if os(macOS)
        columnVisibility = (appModel.selectedSidebar == .today && appModel.selectedArticleID == nil) ? .doubleColumn : .all
#else
        columnVisibility = .automatic
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

    @ViewBuilder
    private var sidebarList: some View {
#if os(macOS)
        List(selection: sidebarSelection) {
            sidebarSections
        }
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

private struct ContentColumnWidthModifier: ViewModifier {
    let selection: ReaderSidebarSelection

    func body(content: Content) -> some View {
#if os(macOS)
        content
            .navigationSplitViewColumnWidth(
                selection == .today ? 760 : 420
            )
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
    let selectedArticleID: UUID?

    var body: some View {
        if let article = selectedArticle {
            StoryDetailView(article: article)
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
}

private enum ArticleListKind {
    case feed(UUID)
    case saved
}

private struct ArticleListView: View {
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
        case .feed:
            "Feed Stories"
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
#else
        List {
            articleRows
        }
#endif
    }

    @ViewBuilder
    private var articleRows: some View {
        ForEach(articles) { article in
            articleRow(article)
        }
    }

    @ViewBuilder
    private func articleRow(_ article: ArticleRecord) -> some View {
#if os(macOS)
        articleRowContent(article)
            .tag(article.uuid)
#else
        Button {
            selectedArticleID = article.uuid
        } label: {
            articleRowContent(article)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowBackground(selectedArticleID == article.uuid ? JippoPalette.panelSoft : Color.clear)
#endif
    }

    private func articleRowContent(_ article: ArticleRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.sourceTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(JippoPalette.highlight)
            Text(article.title)
                .font(.headline)
            Text(article.displaySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                Text(article.displayDateText)
                Text("•")
                Text(article.displayByline)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
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
