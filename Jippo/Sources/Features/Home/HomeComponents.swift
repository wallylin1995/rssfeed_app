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
            HStack(alignment: .top, spacing: 20) {
                if let lead = placements.first, let article = lead.article {
                    StoryArtworkCard(article: article, placement: lead)
                        .onTapGesture { selectedArticleID = article.uuid }
                        .frame(maxWidth: .infinity, minHeight: 520, maxHeight: 620)
                }

                VStack(spacing: 20) {
                    ForEach(Array(placements.dropFirst().prefix(2))) { support in
                        if let article = support.article {
                            HeroSupportPanel(article: article, placement: support)
                                .onTapGesture { selectedArticleID = article.uuid }
                        }
                    }
                }
                .frame(width: 360)
            }

            VStack(spacing: 18) {
                ForEach(placements) { placement in
                    if let article = placement.article {
                        if placement.storyPresentation == .heroLead {
                            StoryArtworkCard(article: article, placement: placement)
                                .onTapGesture { selectedArticleID = article.uuid }
                                .frame(minHeight: 460)
                        } else {
                            HeroSupportPanel(article: article, placement: placement)
                                .onTapGesture { selectedArticleID = article.uuid }
                        }
                    }
                }
            }
        }
    }
}

private struct HeroSupportPanel: View {
    let article: ArticleRecord
    let placement: HomepagePlacementRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(placement.badgeText ?? article.heroBadge)
                    .font(.caption.weight(.black))
                    .kerning(1.1)
                    .foregroundStyle(placement.accent.baseColor)
                Spacer()
                Text(article.displayDateText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(article.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.leading)
                .lineLimit(4)

            Text(article.displaySummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            Spacer()

            HStack {
                Text(article.sourceTitle)
                Text("•")
                Text(article.displayByline)
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .leading)
        .background(JippoPalette.panel)
        .cardChrome(radius: 28)
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
        let minimumCardWidth: CGFloat
        if width > 1400 {
            minimumCardWidth = 330
        } else if width > 980 {
            minimumCardWidth = 300
        } else {
            minimumCardWidth = 260
        }
        return [GridItem(.adaptive(minimum: minimumCardWidth, maximum: 420), spacing: 20, alignment: .top)]
    }
}

private struct StoryTile: View {
    let article: ArticleRecord
    let placement: HomepagePlacementRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StoryArtworkCard(article: article, placement: placement)
                .frame(height: placement.storyPresentation == .feature ? 310 : 230)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(article.sourceTitle)
                    Text("•")
                    Text(article.displayDateText)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

                Text(article.title)
                    .font(placement.storyPresentation == .feature ? .system(size: 28, weight: .bold, design: .rounded) : .title3.bold())
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(article.displaySummary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(placement.storyPresentation == .feature ? 4 : 3)

                HStack {
                    Text(article.displayByline)
                    Spacer()
                    Text(placement.badgeText ?? article.heroBadge)
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
                    .font(placement.storyPresentation == .heroLead ? .system(size: 46, weight: .bold, design: .rounded) : .system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(placement.storyPresentation == .heroLead ? 4 : 3)

                if placement.storyPresentation == .heroLead {
                    Text(article.displaySummary)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(3)
                }

                Text(article.sourceTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(28)
        }
        .overlay(alignment: .bottomLeading) {
            if placement.storyPresentation == .heroLead {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.black.opacity(0.22))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            .padding(18)
        }
        .cardChrome(radius: 34)
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
        VStack(alignment: .leading, spacing: 18) {
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

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 18, alignment: .top)],
                spacing: 18
            ) {
                ForEach(group.articles) { article in
                    TodayCategoryStoryCard(article: article, category: group.category)
                        .onTapGesture { selectedArticleID = article.uuid }
                }
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            articleArtwork
                .frame(height: 220)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(article.sourceTitle)
                    Text("•")
                    Text(article.displayDateText)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(category.color)

                Text(article.title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(article.displaySummary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(article.displayByline)
                        .lineLimit(1)
                    Spacer()
                    Text(category.shortLabel)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .background(JippoPalette.panel)
        .cardChrome(radius: 28)
    }

    private var articleArtwork: some View {
        Group {
            if let imageLink = article.imageLink {
                AsyncImage(url: imageLink) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 0, style: .continuous)
                            .fill(JippoPalette.panelSoft)
                            .overlay { ProgressView() }
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
        }
        .clipped()
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [category.color.opacity(0.9), JippoPalette.panelSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: categorySymbol)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private var categorySymbol: String {
        switch category {
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

private struct TodayShelfStoryCard: View {
    let article: ArticleRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageLink = article.imageLink {
                AsyncImage(url: imageLink) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(JippoPalette.panelSoft)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(JippoPalette.panelSoft)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 158)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(article.sourceTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(article.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(3)

                Text(article.displayDateText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
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
