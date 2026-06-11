import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(JippoPalette.highlight)
                    .frame(width: 24, height: 8)

                Text("CURATED")
                    .font(.caption2.weight(.black))
                    .kerning(1.5)
                    .foregroundStyle(JippoPalette.highlight)
            }

            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct HeroSectionView: View {
    let placements: [HomepagePlacementRecord]
    @Binding var selectedArticleID: UUID?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                if let lead = placements.first, let article = lead.article {
                    StoryArtworkCard(article: article, placement: lead)
                        .onTapGesture { selectedArticleID = article.uuid }
                        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 560)
                }

                if let support = placements.dropFirst().first, let article = support.article {
                    HeroSupportPanel(article: article, placement: support)
                        .onTapGesture { selectedArticleID = article.uuid }
                        .frame(width: 420)
                        .frame(minHeight: 420, maxHeight: 560)
                }
            }
            .cardChrome()

            VStack(spacing: 0) {
                ForEach(placements) { placement in
                    if let article = placement.article {
                        if placement.storyPresentation == .heroLead {
                            StoryArtworkCard(article: article, placement: placement)
                                .onTapGesture { selectedArticleID = article.uuid }
                                .frame(minHeight: 360)
                        } else {
                            HeroSupportPanel(article: article, placement: placement)
                                .onTapGesture { selectedArticleID = article.uuid }
                                .frame(minHeight: 260)
                        }
                    }
                }
            }
            .cardChrome()
        }
    }
}

private struct HeroSupportPanel: View {
    let article: ArticleRecord
    let placement: HomepagePlacementRecord
    @StateObject private var intelligence: ArticleIntelligenceViewModel

    init(article: ArticleRecord, placement: HomepagePlacementRecord) {
        self.article = article
        self.placement = placement
        _intelligence = StateObject(wrappedValue: ArticleIntelligenceViewModel(article: article))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(placement.badgeText ?? article.heroBadge, systemImage: "sparkle")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(article.sourceTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(article.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.leading)

            Text(article.displaySummary)
                .font(.title3)
                .foregroundStyle(.secondary)

            HomepageCardIntelligenceControls(
                intelligence: intelligence,
                accent: placement.accent,
                style: .inline
            )

            Spacer()

            HStack {
                Text(article.displayByline)
                Spacer()
                Image(systemName: "ellipsis")
            }
            .font(.headline)
            .foregroundStyle(.tertiary)
        }
        .padding(24)
        .background(JippoPalette.panel)
    }
}

struct StoryGridSectionView: View {
    let placements: [HomepagePlacementRecord]
    @Binding var selectedArticleID: UUID?

    var body: some View {
        GeometryReader { proxy in
            let columns = gridColumns(for: proxy.size.width)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(placements) { placement in
                    if let article = placement.article {
                        StoryTile(article: article, placement: placement)
                            .onTapGesture { selectedArticleID = article.uuid }
                    }
                }
            }
        }
        .frame(minHeight: 760)
    }

    private func gridColumns(for width: CGFloat) -> [GridItem] {
        let minimumCardWidth: CGFloat = width > 1380 ? 360 : 320
        return [GridItem(.adaptive(minimum: minimumCardWidth, maximum: 520), spacing: 20, alignment: .top)]
    }
}

private struct StoryTile: View {
    let article: ArticleRecord
    let placement: HomepagePlacementRecord
    @StateObject private var intelligence: ArticleIntelligenceViewModel

    init(article: ArticleRecord, placement: HomepagePlacementRecord) {
        self.article = article
        self.placement = placement
        _intelligence = StateObject(wrappedValue: ArticleIntelligenceViewModel(article: article))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StoryArtworkCard(article: article, placement: placement)
                .frame(height: placement.storyPresentation == .feature ? 420 : 260)

            VStack(alignment: .leading, spacing: 12) {
                Text(article.sourceTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(article.title)
                    .font(placement.storyPresentation == .feature ? .system(size: 26, weight: .bold, design: .rounded) : .title2.bold())
                    .multilineTextAlignment(.leading)

                if placement.storyPresentation == .compact {
                    Text(article.displaySummary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HomepageCardIntelligenceControls(
                    intelligence: intelligence,
                    accent: placement.accent,
                    style: .inline
                )

                HStack {
                    Text(article.displayDateText)
                    Text("•")
                    Text(article.displayByline)
                    Spacer()
                    Image(systemName: "ellipsis")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tertiary)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JippoPalette.panel)
        }
        .cardChrome()
    }
}

struct TopicRailSectionView: View {
    let placements: [HomepagePlacementRecord]
    @Binding var selectedArticleID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(placements) { placement in
                    if let article = placement.article {
                        HStack(spacing: 16) {
                            StoryGlyph(accent: placement.accent)
                                .frame(width: 74, height: 74)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(placement.badgeText ?? article.heroBadge)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(JippoPalette.highlight)
                                Text(article.title)
                                    .font(.headline.weight(.bold))
                                    .lineLimit(3)
                                Text(article.sourceTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(18)
                        .frame(width: 360, alignment: .leading)
                        .background(JippoPalette.panel)
                        .cardChrome(radius: 24)
                        .onTapGesture { selectedArticleID = article.uuid }
                    }
                }
            }
        }
    }
}

struct StoryArtworkCard: View {
    let article: ArticleRecord
    let placement: HomepagePlacementRecord
    @StateObject private var intelligence: ArticleIntelligenceViewModel

    init(article: ArticleRecord, placement: HomepagePlacementRecord) {
        self.article = article
        self.placement = placement
        _intelligence = StateObject(wrappedValue: ArticleIntelligenceViewModel(article: article))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageLink = article.imageLink {
                AsyncImage(url: imageLink) { phase in
                    switch phase {
                    case .empty:
                        loadingArtwork
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackArtwork
                    @unknown default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }

            VStack(alignment: .leading, spacing: 10) {
                Text((placement.badgeText ?? article.heroBadge).uppercased())
                    .font(.caption.weight(.black))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.9))

                Text(article.title)
                    .font(placement.storyPresentation == .heroLead ? .system(size: 38, weight: .bold, design: .rounded) : .system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text(article.sourceTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(24)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 10) {
                HomepageCardIntelligenceControls(
                    intelligence: intelligence,
                    accent: placement.accent,
                    style: .overlay
                )

                Circle()
                    .fill(.black.opacity(0.22))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
            }
            .padding(18)
        }
        .clipped()
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(colors: placement.accent.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            RoundedRectangle(cornerRadius: 40)
                .fill(.white.opacity(0.07))
                .frame(width: 240, height: 240)
                .blur(radius: 4)
                .offset(x: 160, y: -120)

            StoryGlyph(accent: placement.accent)
                .frame(width: 250, height: 250)
                .offset(x: 36, y: 28)
        }
    }

    private var loadingArtwork: some View {
        ZStack {
            fallbackArtwork
            ProgressView()
                .tint(.white)
        }
    }
}

struct StoryGlyph: View {
    let accent: StoryAccent

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.14))
            Image(systemName: accent.symbol)
                .resizable()
                .scaledToFit()
                .padding(24)
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct HomepageCardIntelligenceControls: View {
    enum Style {
        case overlay
        case inline
    }

    @ObservedObject var intelligence: ArticleIntelligenceViewModel
    let accent: StoryAccent
    let style: Style
    @State private var expanded = false

    var body: some View {
        VStack(alignment: style == .overlay ? .trailing : .leading, spacing: 10) {
            HStack(spacing: 8) {
                intelligenceButton(
                    title: "摘要",
                    systemImage: "sparkles",
                    prominence: .secondary
                ) {
                    expanded = true
                    Task { await intelligence.summarize() }
                }

                intelligenceButton(
                    title: "繁中",
                    systemImage: "character.book.closed",
                    prominence: .primary
                ) {
                    expanded = true
                    Task { await intelligence.translateToTraditionalChinese() }
                }

                if intelligence.hasOutput {
                    intelligenceButton(
                        title: "清除",
                        systemImage: "xmark",
                        prominence: .secondary
                    ) {
                        intelligence.clearOutputs()
                        expanded = false
                    }
                }

                if intelligence.isSummarizing || intelligence.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style == .overlay ? .white : accent.baseColor)
                        .padding(.horizontal, 6)
                }
            }

            if expanded || intelligence.hasOutput || intelligence.errorMessage != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage = intelligence.errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(secondaryTextColor.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(activeInsightTitle)
                            .font(.caption2.weight(.black))
                            .kerning(1.1)
                            .foregroundStyle(labelColor)

                        Text(activeInsightText)
                            .font(style == .overlay ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(style == .overlay ? 5 : 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(width: style == .overlay ? 280 : nil, alignment: .leading)
                .padding(style == .overlay ? 14 : 12)
                .background(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: style == .overlay ? 18 : 16, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: style == .overlay ? 18 : 16, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: style == .overlay ? .topTrailing : .topLeading)))
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: intelligence.isSummarizing)
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: intelligence.isTranslating)
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: intelligence.hasOutput)
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: expanded)
    }

    private var activeInsightTitle: String {
        if intelligence.translation != nil {
            return "TRANSLATION"
        }
        return "SUMMARY"
    }

    private var activeInsightText: String {
        if let translation = intelligence.translation {
            let translatedSummary = translation.translatedSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let translatedSummary, !translatedSummary.isEmpty {
                return translatedSummary
            }
            return translation.translatedTitle
        }

        let summary = intelligence.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return summary.isEmpty ? "Generate a short editorial takeaway from this story." : summary
    }

    private var primaryTextColor: Color {
        style == .overlay ? .white : .white.opacity(0.94)
    }

    private var secondaryTextColor: Color {
        style == .overlay ? .white.opacity(0.74) : .white.opacity(0.7)
    }

    private var labelColor: Color {
        style == .overlay ? .white.opacity(0.78) : accent.baseColor.opacity(0.94)
    }

    private var backgroundColor: Color {
        switch style {
        case .overlay:
            return .black.opacity(0.34)
        case .inline:
            return JippoPalette.panelSoft.opacity(0.9)
        }
    }

    private var borderColor: Color {
        style == .overlay ? .white.opacity(0.12) : .white.opacity(0.06)
    }

    private func intelligenceButton(title: String, systemImage: String, prominence: IntelligenceButtonProminence, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                if style == .inline {
                    Text(title)
                }
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, style == .inline ? 10 : 9)
            .padding(.vertical, 7)
            .foregroundStyle(buttonForeground(prominence: prominence))
            .background(buttonBackground(prominence: prominence))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func buttonBackground(prominence: IntelligenceButtonProminence) -> Color {
        switch (style, prominence) {
        case (.overlay, .primary):
            return .white.opacity(0.2)
        case (.overlay, .secondary):
            return .black.opacity(0.22)
        case (.inline, .primary):
            return accent.baseColor.opacity(0.24)
        case (.inline, .secondary):
            return .white.opacity(0.06)
        }
    }

    private func buttonForeground(prominence: IntelligenceButtonProminence) -> Color {
        switch style {
        case .overlay:
            return .white
        case .inline:
            return prominence == .primary ? accent.baseColor : .white.opacity(0.88)
        }
    }
}

private enum IntelligenceButtonProminence {
    case primary
    case secondary
}

struct TodayCategoryGroup: Identifiable {
    let category: FeedCategory
    let articles: [ArticleRecord]

    var id: FeedCategory { category }
}

struct TodayCategorySectionsView: View {
    let groups: [TodayCategoryGroup]
    @Binding var selectedArticleID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(groups) { group in
                TodayCategoryClusterView(group: group, selectedArticleID: $selectedArticleID)
            }
        }
    }
}

private struct TodayCategoryClusterView: View {
    let group: TodayCategoryGroup
    @Binding var selectedArticleID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Label(group.category.shortLabel, systemImage: categorySymbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(group.category.color)

                Text("\(group.articles.count) stories")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(group.category.title.uppercased())
                    .font(.caption2.weight(.black))
                    .kerning(1.5)
                    .foregroundStyle(group.category.color.opacity(0.88))
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    featuredCard
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        ForEach(secondaryArticles) { article in
                            TodayCategoryHeadlineRow(article: article)
                                .onTapGesture { selectedArticleID = article.uuid }
                        }
                    }
                    .frame(width: 360)
                }

                VStack(spacing: 16) {
                    featuredCard

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 16, alignment: .top)],
                        spacing: 16
                    ) {
                        ForEach(secondaryArticles) { article in
                            TodayCategoryHeadlineRow(article: article)
                                .onTapGesture { selectedArticleID = article.uuid }
                        }
                    }
                }
            }
        }
    }

    private var featuredCard: some View {
        Group {
            if let article = group.articles.first {
                TodayCategoryStoryCard(article: article, category: group.category)
                    .onTapGesture { selectedArticleID = article.uuid }
            }
        }
    }

    private var secondaryArticles: [ArticleRecord] {
        Array(group.articles.dropFirst())
    }

    private var categorySymbol: String {
        switch group.category {
        case .world:
            return "globe.americas.fill"
        case .technology:
            return "cpu.fill"
        case .ideas:
            return "lightbulb.max.fill"
        case .taiwan:
            return "map.fill"
        case .science:
            return "atom"
        }
    }
}

private struct TodayCategoryStoryCard: View {
    let article: ArticleRecord
    let category: FeedCategory
    @StateObject private var intelligence: ArticleIntelligenceViewModel

    init(article: ArticleRecord, category: FeedCategory) {
        self.article = article
        self.category = category
        _intelligence = StateObject(wrappedValue: ArticleIntelligenceViewModel(article: article))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(article.sourceTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(category.color)

                        Text(article.displayDateText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    Text(article.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }

                Spacer(minLength: 0)

                if let imageLink = article.imageLink {
                    AsyncImage(url: imageLink) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(JippoPalette.panelSoft)
                                .overlay { ProgressView() }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(JippoPalette.panelSoft)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 154, height: 154)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Text(article.displaySummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            HomepageCardIntelligenceControls(
                intelligence: intelligence,
                accent: accent,
                style: .inline
            )

            HStack(spacing: 8) {
                Text(article.displayByline)
                    .lineLimit(1)
                Text("•")
                Text(category.shortLabel)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JippoPalette.panel)
        .cardChrome(radius: 28)
    }

    private var accent: StoryAccent {
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

private struct TodayCategoryHeadlineRow: View {
    let article: ArticleRecord

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let imageLink = article.imageLink {
                AsyncImage(url: imageLink) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(JippoPalette.panelSoft)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(JippoPalette.panelSoft)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(article.sourceTitle)
                    Text("•")
                    Text(article.displayDateText)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JippoPalette.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.05), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func cardChrome(radius: CGFloat = 34) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.05), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }
}
