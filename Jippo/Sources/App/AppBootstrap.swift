import Foundation
import SwiftData

@MainActor
struct AppBootstrap {
    static let automaticRefreshInterval: TimeInterval = 15 * 60
    static let maxArticlesPerFeed = 300
    static let maxUnstarredArticleAge: TimeInterval = 90 * 24 * 60 * 60

    let loader: FeedLoading
    let syncService: RSSSyncService
    let planner: HomepagePlanner

    init(
        loader: FeedLoading = OPMLFeedLoader(),
        syncService: RSSSyncService = RSSSyncService(),
        planner: HomepagePlanner = HomepagePlanner()
    ) {
        self.loader = loader
        self.syncService = syncService
        self.planner = planner
    }

    func ensureFeedSubscriptions(in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<FeedRecord>())
        let subscriptions = loader.loadFeeds()
        let existingByURL = Dictionary(uniqueKeysWithValues: existing.map { ($0.feedURL, $0) })

        for (index, subscription) in subscriptions.enumerated() {
            let key = subscription.url.absoluteString
            if let record = existingByURL[key] {
                record.title = subscription.title
                record.categoryKey = subscription.category.rawValue
                record.displayOrder = index
                record.isActive = true
            } else {
                let record = FeedRecord(
                    feedURL: key,
                    title: subscription.title,
                    categoryKey: subscription.category.rawValue,
                    displayOrder: index
                )
                context.insert(record)
            }
        }

        try context.save()
    }

    func refreshFeedsIfNeeded(in context: ModelContext) async throws {
        let feeds = try context.fetch(FetchDescriptor<FeedRecord>(sortBy: [SortDescriptor(\FeedRecord.displayOrder)]))
        let hasArticles = try !context.fetch(FetchDescriptor<ArticleRecord>()).isEmpty

        guard !feeds.isEmpty else { return }
        if hasArticles { return }

        try await refreshAllFeeds(in: context)
    }

    func refreshFeedsIfStale(in context: ModelContext) async throws {
        let feeds = try context.fetch(FetchDescriptor<FeedRecord>(sortBy: [SortDescriptor(\FeedRecord.displayOrder)]))
        guard !feeds.isEmpty else { return }

        let refreshDeadline = Date.now.addingTimeInterval(-Self.automaticRefreshInterval)
        let needsRefresh = feeds.contains { feed in
            guard let lastFetchedAt = feed.lastFetchedAt else { return true }
            return lastFetchedAt <= refreshDeadline
        }

        guard needsRefresh else { return }
        try await refreshAllFeeds(in: context)
    }

    func refreshAllFeeds(in context: ModelContext) async throws {
        let feeds = try context.fetch(FetchDescriptor<FeedRecord>(sortBy: [SortDescriptor(\FeedRecord.displayOrder)]))
        let subscriptions = feeds.compactMap { record -> FeedSource? in
            guard let url = URL(string: record.feedURL) else { return nil }
            return FeedSource(id: record.uuid, title: record.title, url: url, category: record.category)
        }

        for subscription in subscriptions {
            do {
                let parsedFeed = try await syncService.fetch(subscription: subscription)
                try upsert(parsedFeed: parsedFeed, for: subscription, in: context)
            } catch {
                if let record = try feedRecord(for: subscription.url.absoluteString, in: context) {
                    record.lastSyncError = error.localizedDescription
                    record.lastFetchedAt = .now
                }
            }
        }

        try applyRetentionPolicy(in: context, feeds: feeds)
        _ = try planner.rebuild(in: context)
        try context.save()
    }

    private func feedRecord(for feedURL: String, in context: ModelContext) throws -> FeedRecord? {
        var descriptor = FetchDescriptor<FeedRecord>(predicate: #Predicate { $0.feedURL == feedURL })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func upsert(parsedFeed: ParsedFeed, for subscription: FeedSource, in context: ModelContext) throws {
        guard let feed = try feedRecord(for: subscription.url.absoluteString, in: context) else {
            return
        }

        feed.title = parsedFeed.title
        feed.siteURL = parsedFeed.siteURL
        feed.summary = parsedFeed.summary
        feed.lastFetchedAt = .now
        feed.lastSyncError = nil

        let existingArticles = Dictionary(uniqueKeysWithValues: feed.articles.map { article in
            (article.remoteID ?? article.link, article)
        })

        for parsedArticle in parsedFeed.items {
            let key = parsedArticle.remoteID ?? parsedArticle.link

            if let article = existingArticles[key] {
                hydrate(article: article, from: parsedArticle, feed: feed)
            } else {
                let article = ArticleRecord(
                    remoteID: key,
                    title: parsedArticle.title,
                    link: parsedArticle.link,
                    author: parsedArticle.author,
                    imageURL: parsedArticle.imageURL,
                    publishedAt: parsedArticle.publishedAt,
                    sourceTitle: feed.title,
                    byline: parsedArticle.author,
                    feed: feed
                )
                article.topicLabel = inferTopic(for: article, feed: feed)

                let content = ArticleContentRecord(
                    summary: parsedArticle.summary,
                    text: HTMLContentExtractor.plainText(from: parsedArticle.contentHTML ?? parsedArticle.summary ?? ""),
                    html: parsedArticle.contentHTML,
                    article: article
                )

                article.content = content
                feed.articles.append(article)
                context.insert(article)
                context.insert(content)
            }
        }
    }

    private func hydrate(article: ArticleRecord, from parsedArticle: ParsedArticle, feed: FeedRecord) {
        article.title = parsedArticle.title
        article.link = parsedArticle.link
        article.author = parsedArticle.author
        article.imageURL = parsedArticle.imageURL ?? article.imageURL
        article.publishedAt = parsedArticle.publishedAt ?? article.publishedAt
        article.sourceTitle = feed.title
        article.byline = parsedArticle.author ?? article.byline
        article.topicLabel = inferTopic(for: article, feed: feed)

        if let content = article.content {
            content.summary = parsedArticle.summary ?? content.summary
            let html = parsedArticle.contentHTML ?? parsedArticle.summary ?? ""
            content.text = HTMLContentExtractor.plainText(from: html)
            content.html = parsedArticle.contentHTML ?? content.html
        } else {
            article.content = ArticleContentRecord(
                summary: parsedArticle.summary,
                text: HTMLContentExtractor.plainText(from: parsedArticle.contentHTML ?? parsedArticle.summary ?? ""),
                html: parsedArticle.contentHTML,
                article: article
            )
        }
    }

    private func inferTopic(for article: ArticleRecord, feed: FeedRecord) -> String {
        let blob = [article.title, article.content?.summary, feed.title]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        switch feed.category {
        case .technology:
            return blob.contains("ai") ? "AI 工具" : "科技"
        case .taiwan:
            if blob.contains("農") || blob.contains("food") || blob.contains("食") {
                return "農業"
            }
            return "台灣"
        case .science:
            return "科學"
        case .ideas:
            return "觀點"
        case .world:
            return "世界"
        }
    }

    private func applyRetentionPolicy(in context: ModelContext, feeds: [FeedRecord]) throws {
        let ageCutoff = Date.now.addingTimeInterval(-Self.maxUnstarredArticleAge)
        var articleIDsMarkedForDeletion = Set<UUID>()

        for feed in feeds {
            let sortedArticles = feed.articles.sorted(using: [
                SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
                SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
            ])

            var preservedCount = 0
            for article in sortedArticles {
                if article.starred {
                    continue
                }

                let referenceDate = article.publishedAt ?? article.receivedAt
                let isExpired = referenceDate < ageCutoff
                let exceedsPerFeedLimit = preservedCount >= Self.maxArticlesPerFeed

                if isExpired || exceedsPerFeedLimit {
                    articleIDsMarkedForDeletion.insert(article.uuid)
                } else {
                    preservedCount += 1
                }
            }
        }

        guard !articleIDsMarkedForDeletion.isEmpty else { return }

        let articleDescriptor = FetchDescriptor<ArticleRecord>()
        let allArticles = try context.fetch(articleDescriptor)
        for article in allArticles where articleIDsMarkedForDeletion.contains(article.uuid) {
            context.delete(article)
        }
    }
}
