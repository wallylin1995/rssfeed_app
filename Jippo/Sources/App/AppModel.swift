import Foundation
import Combine
import SwiftData

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSidebar: ReaderSidebarSelection = .today
    @Published var selectedArticleID: UUID?
    @Published var isBootstrapped = false
    @Published var isRefreshing = false
    @Published var lastErrorMessage: String?

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
}

enum ReaderSidebarSelection: Hashable {
    case today
    case saved
    case feed(UUID)
}
