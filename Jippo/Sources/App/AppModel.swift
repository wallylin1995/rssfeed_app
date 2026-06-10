import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var feeds: [FeedSource]
    @Published var homepage: HomepagePlan
    @Published var selectedTab: AppTab = .home

    init(loader: FeedLoading = OPMLFeedLoader()) {
        let loadedFeeds = loader.loadFeeds()
        feeds = loadedFeeds
        homepage = HomepagePlan.sample(feeds: loadedFeeds)
    }
}
