import Foundation
import SwiftData

@Model
final class FeedRecord {
    @Attribute(.unique) var uuid: UUID
    @Attribute(.unique) var feedURL: String
    var title: String
    var categoryKey: String
    var siteURL: String?
    var summary: String?
    var displayOrder: Int
    var isActive: Bool
    var lastFetchedAt: Date?
    var lastSyncError: String?
    @Relationship(deleteRule: .cascade, inverse: \ArticleRecord.feed) var articles: [ArticleRecord]

    init(
        uuid: UUID = UUID(),
        feedURL: String,
        title: String,
        categoryKey: String,
        siteURL: String? = nil,
        summary: String? = nil,
        displayOrder: Int = 0,
        isActive: Bool = true,
        lastFetchedAt: Date? = nil,
        lastSyncError: String? = nil
    ) {
        self.uuid = uuid
        self.feedURL = feedURL
        self.title = title
        self.categoryKey = categoryKey
        self.siteURL = siteURL
        self.summary = summary
        self.displayOrder = displayOrder
        self.isActive = isActive
        self.lastFetchedAt = lastFetchedAt
        self.lastSyncError = lastSyncError
        articles = []
    }
}

@Model
final class ArticleRecord {
    @Attribute(.unique) var uuid: UUID
    var remoteID: String?
    var title: String
    var link: String
    var author: String?
    var imageURL: String?
    var publishedAt: Date?
    var receivedAt: Date
    var unread: Bool
    var starred: Bool
    var topicLabel: String?
    var sourceTitle: String
    var byline: String?
    var feed: FeedRecord?
    @Relationship(deleteRule: .cascade, inverse: \ArticleContentRecord.article) var content: ArticleContentRecord?
    @Relationship(deleteRule: .cascade, inverse: \HomepagePlacementRecord.article) var placements: [HomepagePlacementRecord]

    init(
        uuid: UUID = UUID(),
        remoteID: String? = nil,
        title: String,
        link: String,
        author: String? = nil,
        imageURL: String? = nil,
        publishedAt: Date? = nil,
        receivedAt: Date = .now,
        unread: Bool = true,
        starred: Bool = false,
        topicLabel: String? = nil,
        sourceTitle: String,
        byline: String? = nil,
        feed: FeedRecord? = nil
    ) {
        self.uuid = uuid
        self.remoteID = remoteID
        self.title = title
        self.link = link
        self.author = author
        self.imageURL = imageURL
        self.publishedAt = publishedAt
        self.receivedAt = receivedAt
        self.unread = unread
        self.starred = starred
        self.topicLabel = topicLabel
        self.sourceTitle = sourceTitle
        self.byline = byline
        self.feed = feed
        placements = []
    }
}

@Model
final class ArticleContentRecord {
    @Attribute(.unique) var uuid: UUID
    var summary: String?
    var text: String?
    @Attribute(.externalStorage) var html: String?
    var article: ArticleRecord?

    init(
        uuid: UUID = UUID(),
        summary: String? = nil,
        text: String? = nil,
        html: String? = nil,
        article: ArticleRecord? = nil
    ) {
        self.uuid = uuid
        self.summary = summary
        self.text = text
        self.html = html
        self.article = article
    }
}

@Model
final class HomepagePlanRecord {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var subtitle: String
    var generatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \HomepageSectionRecord.plan) var sections: [HomepageSectionRecord]

    init(
        uuid: UUID = UUID(),
        title: String,
        subtitle: String,
        generatedAt: Date = .now
    ) {
        self.uuid = uuid
        self.title = title
        self.subtitle = subtitle
        self.generatedAt = generatedAt
        sections = []
    }
}

@Model
final class HomepageSectionRecord {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var subtitle: String
    var semanticType: String
    var displayOrder: Int
    var plan: HomepagePlanRecord?
    @Relationship(deleteRule: .cascade, inverse: \HomepagePlacementRecord.section) var placements: [HomepagePlacementRecord]

    init(
        uuid: UUID = UUID(),
        title: String,
        subtitle: String,
        semanticType: String,
        displayOrder: Int,
        plan: HomepagePlanRecord? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.subtitle = subtitle
        self.semanticType = semanticType
        self.displayOrder = displayOrder
        self.plan = plan
        placements = []
    }
}

@Model
final class HomepagePlacementRecord {
    @Attribute(.unique) var uuid: UUID
    var displayOrder: Int
    var visualWeight: String
    var badgeText: String?
    var section: HomepageSectionRecord?
    var article: ArticleRecord?

    init(
        uuid: UUID = UUID(),
        displayOrder: Int,
        visualWeight: String,
        badgeText: String? = nil,
        section: HomepageSectionRecord? = nil,
        article: ArticleRecord? = nil
    ) {
        self.uuid = uuid
        self.displayOrder = displayOrder
        self.visualWeight = visualWeight
        self.badgeText = badgeText
        self.section = section
        self.article = article
    }
}

extension FeedRecord {
    var category: FeedCategory {
        FeedCategory(rawValue: categoryKey) ?? .world
    }
}
