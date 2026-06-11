import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: [SortDescriptor(\HomepagePlanRecord.generatedAt, order: .reverse)]) private var plans: [HomepagePlanRecord]
    @Query(
        sort: [
            SortDescriptor(\ArticleRecord.publishedAt, order: .reverse),
            SortDescriptor(\ArticleRecord.receivedAt, order: .reverse)
        ]
    ) private var recentArticles: [ArticleRecord]
    @Binding var selectedArticleID: UUID?

    var body: some View {
        Group {
            if let plan = plans.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 44) {
                        HomeHeaderView(
                            title: plan.title,
                            subtitle: plan.subtitle,
                            digest: makeDigest(from: plan),
                            categoryGroups: categoryGroups
                        )

                        if let heroSection = section(for: .hero, in: plan) {
                            VStack(alignment: .leading, spacing: 18) {
                                SectionHeaderView(
                                    title: heroSection.title,
                                    subtitle: heroSection.subtitle
                                )
                                HeroSectionView(
                                    placements: orderedPlacements(for: heroSection),
                                    selectedArticleID: $selectedArticleID
                                )
                            }
                        }

                        if let topStoriesSection = section(for: .topStories, in: plan) {
                            VStack(alignment: .leading, spacing: 18) {
                                SectionHeaderView(
                                    title: topStoriesSection.title,
                                    subtitle: topStoriesSection.subtitle
                                )
                                StoryGridSectionView(
                                    placements: orderedPlacements(for: topStoriesSection),
                                    selectedArticleID: $selectedArticleID
                                )
                            }
                        }

                        if !categoryGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                SectionHeaderView(
                                    title: "By Category",
                                    subtitle: "A calmer second pass through the rest of your feed, grouped into clearer desks."
                                )
                                TodayCategorySectionsView(
                                    groups: categoryGroups,
                                    selectedArticleID: $selectedArticleID
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "No Homepage Yet",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Refresh the feeds to generate your first editorial homepage.")
                )
            }
        }
        .overlay {
            HomeBackgroundView()
                .allowsHitTesting(false)
        }
        .background(JippoPalette.canvas.ignoresSafeArea())
        .navigationTitle("Jippo")
        .jippoTitleDisplayMode(.large)
    }

    private func section(for semanticType: HomepageSemanticType, in plan: HomepagePlanRecord) -> HomepageSectionRecord? {
        plan.sections.first(where: { $0.semanticType == semanticType.rawValue })
    }

    private func orderedPlacements(for section: HomepageSectionRecord) -> [HomepagePlacementRecord] {
        section.placements.sorted(using: [SortDescriptor(\HomepagePlacementRecord.displayOrder)])
    }

    private func makeDigest(from plan: HomepagePlanRecord) -> HomepageDigest {
        let placements = plan.sections.flatMap(\.placements)
        let articles = placements.compactMap(\.article)
        let uniqueFeeds = Set(articles.compactMap { $0.feed?.uuid })
        let topics = Array(
            Set(
                articles.compactMap { article in
                    article.topicLabel ?? article.feed?.category.shortLabel
                }
            )
        )
        .sorted()

        return HomepageDigest(
            storyCount: articles.count,
            feedCount: uniqueFeeds.count,
            topicLabels: Array(topics.prefix(4)),
            generatedAt: plan.generatedAt
        )
    }

    private var categoryGroups: [TodayCategoryGroup] {
        let plannedIDs = Set(
            plans.first?
                .sections
                .flatMap(\.placements)
                .compactMap(\.article?.uuid) ?? []
        )

        let remainingArticles = recentArticles
            .filter { !plannedIDs.contains($0.uuid) }
            .prefix(24)

        let grouped = Dictionary(grouping: remainingArticles) { article in
            article.feed?.category ?? .world
        }

        return FeedCategory.allCases.compactMap { category in
            guard let articles = grouped[category] else { return nil }
            let unique = Array(articles.prefix(3))
            guard unique.count >= 2 else { return nil }

            return TodayCategoryGroup(
                category: category,
                articles: unique
            )
        }
        .prefix(3)
        .map { $0 }
    }
}

struct HomepageDigest {
    let storyCount: Int
    let feedCount: Int
    let topicLabels: [String]
    let generatedAt: Date
}

struct HomeHeaderView: View {
    let title: String
    let subtitle: String
    let digest: HomepageDigest
    let categoryGroups: [TodayCategoryGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            mastheadCopy

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    TodayBriefStrip(digest: digest, categoryGroups: categoryGroups)
                    TodaySignalRow(digest: digest)
                        .frame(width: 420)
                }

                VStack(alignment: .leading, spacing: 18) {
                    TodayBriefStrip(digest: digest, categoryGroups: categoryGroups)
                    TodaySignalRow(digest: digest)
                }
            }
        }
    }

    private var mastheadCopy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TODAY")
                .font(.caption.weight(.black))
                .kerning(2.2)
                .foregroundStyle(JippoPalette.highlight)

            Text(title)
                .font(.system(size: 60, weight: .bold, design: .rounded))

            Text(subtitle)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)

            Label("Real feed sync + local persistence + editorial layout planning", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JippoPalette.highlight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayBriefStrip: View {
    let digest: HomepageDigest
    let categoryGroups: [TodayCategoryGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(JippoPalette.highlight)
                    .frame(width: 8, height: 8)

                Text("Morning Brief")
                    .font(.headline.weight(.bold))
            }

            Text(briefCopy)
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 10) {
                ForEach(Array(categoryGroups.prefix(4))) { group in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(group.category.color)
                            .frame(width: 8, height: 8)

                        Text(group.category.shortLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    JippoPalette.panelSoft.opacity(0.96),
                    JippoPalette.panel.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cardChrome(radius: 30)
    }

    private var briefCopy: String {
        let labels = categoryGroups.prefix(3).map(\.category.shortLabel)
        if labels.count >= 3 {
            return "\(labels[0])、\(labels[1]) 與 \(labels[2]) 正在主導今天的版面節奏。"
        }
        if let first = labels.first {
            return "\(first) 類別仍然最活躍，首頁已整理成更清楚的編排節奏。"
        }
        return "Your front page is now arranged as a calmer newsroom-style edition."
    }
}

private struct TodaySignalRow: View {
    let digest: HomepageDigest

    var body: some View {
        HStack(spacing: 14) {
            metricCard(title: "Stories", value: "\(digest.storyCount)", note: "fresh articles")
            metricCard(title: "Feeds", value: "\(digest.feedCount)", note: "active sources")
            metricCard(
                title: "Updated",
                value: digest.generatedAt.formatted(date: .omitted, time: .shortened),
                note: digest.generatedAt.formatted(date: .abbreviated, time: .omitted)
            )
        }
    }

    private func metricCard(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .kerning(1.2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(title == "Updated" ? .title3.weight(.bold) : .system(size: 34, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(note)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(JippoPalette.panelSoft.opacity(0.7))
        .cardChrome(radius: 24)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }

            lineWidth += (lineWidth > 0 ? spacing : 0) + size.width
            lineHeight = max(lineHeight, size.height)
        }

        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursor = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > bounds.maxX, cursor.x > bounds.minX {
                cursor.x = bounds.minX
                cursor.y += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: cursor,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            cursor.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct HomeBackgroundView: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [JippoPalette.highlight.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 520
            )
            .offset(x: -80, y: -140)

            RadialGradient(
                colors: [Color.white.opacity(0.05), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .offset(x: 120, y: -120)
        }
        .ignoresSafeArea()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView(selectedArticleID: .constant(nil))
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
    }
}
