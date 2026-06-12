import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSidebar: ReaderSidebarSelection = .today
    @Published var selectedArticleID: UUID?
    @Published var articleSearchText = ""
    @Published var isBootstrapped = false
    @Published var isRefreshing = false
    @Published var lastErrorMessage: String?
    @Published var detailToolbarContext = ReaderDetailToolbarContext()

    let bootstrap: AppBootstrap

    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
    }

    convenience init() {
        self.init(bootstrap: AppBootstrap())
    }

    func bootstrapIfNeeded(context: ModelContext) async {
        guard !isBootstrapped else { return }
        isBootstrapped = true

        do {
            try bootstrap.ensureFeedSubscriptions(in: context)
            try await bootstrap.refreshFeedsIfNeeded(in: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshAll(context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await bootstrap.refreshAllFeeds(in: context)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshIfStale(context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await bootstrap.refreshFeedsIfStale(in: context)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func setDetailToolbarContext(_ context: ReaderDetailToolbarContext) {
        detailToolbarContext = context
    }

    func clearDetailToolbarContext(for articleID: UUID? = nil) {
        guard articleID == nil || detailToolbarContext.articleID == articleID else { return }
        detailToolbarContext = ReaderDetailToolbarContext()
    }
}

enum ReaderSidebarSelection: Hashable {
    case today
    case saved
    case feed(UUID)
}

struct ReaderDetailToolbarContext {
    var articleID: UUID?
    var articleLink: URL?
    var presentationMode: DetailPresentationMode = .rss
    var canGoPrevious = false
    var canGoNext = false
    var unread = false
    var starred = false
    var canRunIntelligenceActions = false
    var intelligenceBusy = false
    var hasIntelligenceOutput = false
    var canGoBack = false
    var canGoForward = false
    var webIsLoading = false
    var goPrevious: (() -> Void)?
    var goNext: (() -> Void)?
    var toggleUnread: (() -> Void)?
    var toggleStar: (() -> Void)?
    var setPresentationMode: ((DetailPresentationMode) -> Void)?
    var summarize: (() -> Void)?
    var translateTraditionalChinese: (() -> Void)?
    var translateEnglish: (() -> Void)?
    var clearIntelligence: (() -> Void)?
    var webBack: (() -> Void)?
    var webForward: (() -> Void)?
    var webReloadOrStop: (() -> Void)?

    var isVisible: Bool {
        articleID != nil
    }
}

enum DetailPresentationMode: String, CaseIterable, Identifiable {
    case rss
    case reader
    case original

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rss: "RSS"
        case .reader: "Reader"
        case .original: "Original"
        }
    }
}

enum DetailReaderWidth: String, CaseIterable, Identifiable {
    case focused
    case comfortable
    case expansive

    var id: String { rawValue }

    var maxWidth: CGFloat {
        switch self {
        case .focused: 760
        case .comfortable: 900
        case .expansive: 1040
        }
    }

    var label: String {
        switch self {
        case .focused: "Narrow"
        case .comfortable: "Comfort"
        case .expansive: "Wide"
        }
    }
}

enum DetailReaderTheme: String, CaseIterable, Identifiable {
    case graphite
    case paper
    case sepia

    var id: String { rawValue }

    var label: String {
        switch self {
        case .graphite: "Graphite"
        case .paper: "Paper"
        case .sepia: "Sepia"
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
