import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text(subtitle)
                .font(.headline)
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
        if width > 1100 {
            return Array(repeating: GridItem(.flexible(), spacing: 20), count: 2)
        } else {
            return [GridItem(.flexible(), spacing: 20)]
        }
    }
}

private struct StoryTile: View {
    let article: ArticleRecord
    let placement: HomepagePlacementRecord

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
