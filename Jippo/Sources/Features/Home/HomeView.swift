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
                    VStack(alignment: .leading, spacing: 40) {
                        HomeHeaderView(
                            title: plan.title,
                            subtitle: plan.subtitle,
                            digest: makeDigest(from: plan),
                            categoryGroups: categoryGroups
                        )

                        ForEach(plan.sections.sorted(using: [SortDescriptor(\HomepageSectionRecord.displayOrder)])) { section in
                            VStack(alignment: .leading, spacing: 18) {
                                SectionHeaderView(title: section.title, subtitle: section.subtitle)

                                switch section.style {
                                case .hero:
                                    HeroSectionView(placements: orderedPlacements(for: section), selectedArticleID: $selectedArticleID)
                                case .grid:
                                    StoryGridSectionView(placements: orderedPlacements(for: section), selectedArticleID: $selectedArticleID)
                                case .rail:
                                    TopicRailSectionView(placements: orderedPlacements(for: section), selectedArticleID: $selectedArticleID)
                                }
                            }
                        }

                        if !categoryGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                SectionHeaderView(
                                    title: "Category Briefings",
                                    subtitle: "A wider front page grouped from your live feed universe."
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
                    .frame(maxWidth: 1720)
                    .frame(maxWidth: .infinity)
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
        let grouped = Dictionary(grouping: recentArticles.prefix(48)) { article in
            article.feed?.category ?? .world
        }

        return FeedCategory.allCases.compactMap { category in
            guard let articles = grouped[category] else { return nil }
            let unique = Array(articles.prefix(4))
            guard !unique.isEmpty else { return nil }

            return TodayCategoryGroup(
                category: category,
                articles: unique
            )
        }
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    mastheadCopy
                    TodayBriefStrip(digest: digest, categoryGroups: categoryGroups)
                }

                VStack(spacing: 18) {
                    TodaySignalCard(digest: digest)
                    TodayMomentumCard(digest: digest, categoryGroups: categoryGroups)
                }
                .frame(width: 390)
            }

            VStack(alignment: .leading, spacing: 20) {
                mastheadCopy
                TodayBriefStrip(digest: digest, categoryGroups: categoryGroups)
                TodaySignalCard(digest: digest)
                TodayMomentumCard(digest: digest, categoryGroups: categoryGroups)
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

            HStack(spacing: 10) {
                Text("Updated \(digest.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text("\(digest.storyCount) stories in play")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
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
                .font(.system(size: 24, weight: .medium, design: .serif))
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
        .padding(22)
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
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var briefCopy: String {
        let labels = categoryGroups.prefix(3).map(\.category.shortLabel)
        if labels.count >= 3 {
            return "\(labels[0])、\(labels[1]) 與 \(labels[2]) 正在主導今天的版面節奏。"
        }
        if let first = labels.first {
            return "\(first) 類別仍然最活躍，首頁已整理成可快速掃讀的 front page。"
        }
        return "Your front page is now arranged as a richer newsroom-style edition."
    }
}

private struct TodaySignalCard: View {
    let digest: HomepageDigest

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Newsroom Pulse")
                    .font(.headline.weight(.bold))

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(JippoPalette.highlight)
            }

            HStack(spacing: 12) {
                statCard(value: "\(digest.storyCount)", label: "stories")
                statCard(value: "\(digest.feedCount)", label: "feeds")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Top tracks")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 10) {
                    ForEach(digest.topicLabels, id: \.self) { topic in
                        Text(topic)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(JippoPalette.panelSoft)
                            .clipShape(Capsule())
                    }
                }
            }

            Text("Updated \(digest.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(JippoPalette.panel.opacity(0.9))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .kerning(1.4)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(JippoPalette.panelSoft.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TodayMomentumCard: View {
    let digest: HomepageDigest
    let categoryGroups: [TodayCategoryGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Priority Lanes")
                .font(.headline.weight(.bold))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(categoryGroups.prefix(3).enumerated()), id: \.offset) { index, group in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(group.category.color.opacity(0.18))
                            Text("\(index + 1)")
                                .font(.caption.weight(.black))
                                .foregroundStyle(group.category.color)
                        }
                        .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.category.title)
                                .font(.subheadline.weight(.bold))
                            Text(group.articles.first?.title ?? "")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                }
            }

            Divider()
                .overlay(.white.opacity(0.06))

            Text("Edition compiled from \(digest.feedCount) live sources and tuned for fast scanning across a wide desktop window.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(JippoPalette.panel.opacity(0.9))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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
