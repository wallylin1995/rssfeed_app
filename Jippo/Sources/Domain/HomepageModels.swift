import SwiftUI

enum HomepageSectionStyle {
    case hero
    case grid
    case rail
}

enum StoryPresentation: Hashable {
    case heroLead
    case heroSupport
    case feature
    case compact
    case rail
}

enum StoryAccent: Hashable {
    case sunset
    case electric
    case forest
    case currant
    case ice
    case berry
    case plum
    case mint
    case amber

    var colors: [Color] {
        switch self {
        case .sunset:
            [Color(red: 0.93, green: 0.80, blue: 0.37), Color(red: 0.78, green: 0.39, blue: 0.22)]
        case .electric:
            [Color(red: 0.25, green: 0.48, blue: 0.94), Color(red: 0.08, green: 0.14, blue: 0.43)]
        case .forest:
            [Color(red: 0.47, green: 0.72, blue: 0.38), Color(red: 0.15, green: 0.32, blue: 0.15)]
        case .currant:
            [Color(red: 0.96, green: 0.33, blue: 0.45), Color(red: 0.35, green: 0.09, blue: 0.16)]
        case .ice:
            [Color(red: 0.75, green: 0.89, blue: 0.97), Color(red: 0.35, green: 0.48, blue: 0.69)]
        case .berry:
            [Color(red: 0.82, green: 0.35, blue: 0.49), Color(red: 0.38, green: 0.14, blue: 0.29)]
        case .plum:
            [Color(red: 0.71, green: 0.53, blue: 0.92), Color(red: 0.27, green: 0.17, blue: 0.43)]
        case .mint:
            [Color(red: 0.62, green: 0.90, blue: 0.80), Color(red: 0.16, green: 0.42, blue: 0.35)]
        case .amber:
            [Color(red: 0.98, green: 0.72, blue: 0.31), Color(red: 0.54, green: 0.28, blue: 0.11)]
        }
    }

    var symbol: String {
        switch self {
        case .sunset:
            "sun.max.fill"
        case .electric:
            "bolt.fill"
        case .forest:
            "leaf.fill"
        case .currant:
            "newspaper.fill"
        case .ice:
            "aqi.medium"
        case .berry:
            "dot.radiowaves.left.and.right"
        case .plum:
            "text.book.closed.fill"
        case .mint:
            "sparkles"
        case .amber:
            "lightbulb.max.fill"
        }
    }
}

extension FeedCategory {
    var color: Color {
        switch self {
        case .world:
            Color(red: 0.96, green: 0.33, blue: 0.45)
        case .technology:
            Color(red: 0.25, green: 0.48, blue: 0.94)
        case .ideas:
            Color(red: 0.71, green: 0.53, blue: 0.92)
        case .taiwan:
            Color(red: 0.82, green: 0.35, blue: 0.49)
        case .science:
            Color(red: 0.62, green: 0.90, blue: 0.80)
        }
    }
}

extension HomepageSectionRecord {
    var style: HomepageSectionStyle {
        switch semanticType {
        case HomepageSemanticType.hero.rawValue:
            .hero
        case HomepageSemanticType.topicRail.rawValue:
            .rail
        default:
            .grid
        }
    }
}

extension HomepagePlacementRecord {
    var storyPresentation: StoryPresentation {
        switch visualWeight {
        case HomepageVisualWeight.heroLead.rawValue:
            .heroLead
        case HomepageVisualWeight.heroSupport.rawValue:
            .heroSupport
        case HomepageVisualWeight.feature.rawValue:
            .feature
        case HomepageVisualWeight.rail.rawValue:
            .rail
        default:
            .compact
        }
    }

    var accent: StoryAccent {
        guard let category = article?.feed?.category else { return .currant }
        switch category {
        case .world:
            return .currant
        case .technology:
            return .electric
        case .ideas:
            return .plum
        case .taiwan:
            return .berry
        case .science:
            return .mint
        }
    }
}

extension ArticleRecord {
    var displaySummary: String {
        if let summary = content?.summary, !summary.isEmpty {
            return summary
        }
        if let text = content?.text, !text.isEmpty {
            return String(text.prefix(220))
        }
        return "No summary yet."
    }

    var displayDateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: publishedAt ?? receivedAt, relativeTo: .now)
    }

    var displayByline: String {
        author ?? sourceTitle
    }

    var heroBadge: String {
        topicLabel ?? feed?.category.shortLabel ?? "News"
    }

    var imageLink: URL? {
        guard let imageURL, let url = URL(string: imageURL) else { return nil }
        return url
    }

    var articleLink: URL? {
        URL(string: link)
    }
}
