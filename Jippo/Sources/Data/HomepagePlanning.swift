import Foundation
import SwiftData

enum HomepageSemanticType: String {
    case hero
    case topStories
    case topicRail
}

enum HomepageVisualWeight: String {
    case heroLead
    case heroSupport
    case feature
    case compact
    case rail
}

struct HomepagePlanner {
    @MainActor
    func rebuild(in context: ModelContext) throws -> HomepagePlanRecord? {
        let articleDescriptor = FetchDescriptor<ArticleRecord>(
            sortBy: [
                SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
                SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
            ]
        )
        let allArticles = try context.fetch(articleDescriptor)

        guard !allArticles.isEmpty else {
            try clearExistingPlans(in: context)
            try context.save()
            return nil
        }

        try clearExistingPlans(in: context)

        let plan = HomepagePlanRecord(
            title: "Jippo",
            subtitle: "AI-style editorial homepage built from your real RSS articles."
        )
        context.insert(plan)

        let heroArticles = Array(allArticles.prefix(2))
        let topStories = Array(allArticles.dropFirst(2).prefix(6))
        let topicRails = makeTopicRails(from: allArticles)

        appendSection(
            title: "Editors' Pick",
            subtitle: "A high-signal front page assembled from your newest stories.",
            semanticType: .hero,
            placements: zip(heroArticles, [HomepageVisualWeight.heroLead, .heroSupport]).enumerated().map { index, pair in
                PlacementPlan(article: pair.0, weight: pair.1, displayOrder: index, badgeText: pair.0.feed?.category.shortLabel)
            },
            order: 0,
            to: plan,
            in: context
        )

        appendSection(
            title: "Top Stories",
            subtitle: "Live stories fetched from your feeds and ranked by freshness.",
            semanticType: .topStories,
            placements: topStories.enumerated().map { index, article in
                PlacementPlan(
                    article: article,
                    weight: index < 2 ? .feature : .compact,
                    displayOrder: index,
                    badgeText: article.feed?.title
                )
            },
            order: 1,
            to: plan,
            in: context
        )

        if !topicRails.isEmpty {
            appendSection(
                title: "Topic Rails",
                subtitle: "Lightweight clusters inferred from your feeds and article themes.",
                semanticType: .topicRail,
                placements: topicRails.enumerated().map { index, article in
                    PlacementPlan(
                        article: article,
                        weight: .rail,
                        displayOrder: index,
                        badgeText: article.topicLabel ?? article.feed?.category.shortLabel
                    )
                },
                order: 2,
                to: plan,
                in: context
            )
        }

        try context.save()
        return plan
    }

    @MainActor
    private func clearExistingPlans(in context: ModelContext) throws {
        let planDescriptor = FetchDescriptor<HomepagePlanRecord>()
        let plans = try context.fetch(planDescriptor)
        for plan in plans {
            context.delete(plan)
        }
    }

    @MainActor
    private func appendSection(
        title: String,
        subtitle: String,
        semanticType: HomepageSemanticType,
        placements: [PlacementPlan],
        order: Int,
        to plan: HomepagePlanRecord,
        in context: ModelContext
    ) {
        guard !placements.isEmpty else { return }

        let section = HomepageSectionRecord(
            title: title,
            subtitle: subtitle,
            semanticType: semanticType.rawValue,
            displayOrder: order,
            plan: plan
        )
        context.insert(section)
        plan.sections.append(section)

        for placementPlan in placements {
            let placement = HomepagePlacementRecord(
                displayOrder: placementPlan.displayOrder,
                visualWeight: placementPlan.weight.rawValue,
                badgeText: placementPlan.badgeText,
                section: section,
                article: placementPlan.article
            )
            context.insert(placement)
            section.placements.append(placement)
            placementPlan.article.placements.append(placement)
        }
    }

    private func makeTopicRails(from articles: [ArticleRecord]) -> [ArticleRecord] {
        var seenTopics = Set<String>()
        var selected: [ArticleRecord] = []

        for article in articles {
            let topic = article.topicLabel ?? article.feed?.category.shortLabel ?? "News"
            guard !seenTopics.contains(topic) else { continue }
            seenTopics.insert(topic)
            selected.append(article)
            if selected.count == 5 {
                break
            }
        }

        return selected
    }
}

private struct PlacementPlan {
    let article: ArticleRecord
    let weight: HomepageVisualWeight
    let displayOrder: Int
    let badgeText: String?
}
