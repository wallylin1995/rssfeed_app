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
    let cards: [StoryCard]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                if let lead = cards.first {
                    StoryArtworkCard(card: lead)
                        .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 560)
                }

                if let support = cards.dropFirst().first {
                    HeroSupportPanel(card: support)
                        .frame(width: 420)
                        .frame(minHeight: 420, maxHeight: 560)
                }
            }
            .cardChrome()

            VStack(spacing: 0) {
                ForEach(cards) { card in
                    if card.presentation == .heroLead {
                        StoryArtworkCard(card: card)
                            .frame(minHeight: 360)
                    } else {
                        HeroSupportPanel(card: card)
                            .frame(minHeight: 260)
                    }
                }
            }
            .cardChrome()
        }
    }
}

private struct HeroSupportPanel: View {
    let card: StoryCard

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(card.categoryLabel, systemImage: "sparkle")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(card.source.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(card.headline)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.leading)

            Text(card.summary)
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Text(card.byline)
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
    let cards: [StoryCard]

    var body: some View {
        GeometryReader { proxy in
            let columns = gridColumns(for: proxy.size.width)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(cards) { card in
                    NavigationLink(value: card) {
                        StoryTile(card: card)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: StoryCard.self) { card in
                StoryDetailView(card: card)
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
    let card: StoryCard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StoryArtworkCard(card: card)
                .frame(height: card.presentation == .feature ? 420 : 260)

            VStack(alignment: .leading, spacing: 12) {
                Text(card.source.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(card.headline)
                    .font(card.presentation == .feature ? .system(size: 26, weight: .bold, design: .rounded) : .title2.bold())
                    .multilineTextAlignment(.leading)

                if card.presentation == .compact {
                    Text(card.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(card.timeLabel)
                    Text("•")
                    Text(card.byline)
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
    let cards: [StoryCard]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(cards) { card in
                    NavigationLink(value: card) {
                        HStack(spacing: 16) {
                            StoryGlyph(accent: card.accent)
                                .frame(width: 74, height: 74)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(card.categoryLabel)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(JippoPalette.highlight)
                                Text(card.headline)
                                    .font(.headline.weight(.bold))
                                    .lineLimit(3)
                                Text(card.source.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(18)
                        .frame(width: 360, alignment: .leading)
                        .background(JippoPalette.panel)
                        .cardChrome(radius: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: StoryCard.self) { card in
            StoryDetailView(card: card)
        }
    }
}

struct FeedCategoryOverview: View {
    let feeds: [FeedSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Feed Landscape")
                .font(.title.bold())

            ForEach(FeedCategory.allCases, id: \.self) { category in
                let categoryFeeds = feeds.filter { $0.category == category }
                if !categoryFeeds.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(category.shortLabel)
                                .font(.headline.bold())
                            Text(category.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], alignment: .leading, spacing: 10) {
                            ForEach(categoryFeeds) { feed in
                                Text(feed.title)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(JippoPalette.panelSoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(JippoPalette.panel)
                    .cardChrome(radius: 28)
                }
            }
        }
    }
}

struct StoryArtworkCard: View {
    let card: StoryCard

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: card.accent.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            RoundedRectangle(cornerRadius: 40)
                .fill(.white.opacity(0.07))
                .frame(width: 240, height: 240)
                .blur(radius: 4)
                .offset(x: 160, y: -120)

            StoryGlyph(accent: card.accent)
                .frame(width: 250, height: 250)
                .offset(x: 36, y: 28)

            VStack(alignment: .leading, spacing: 10) {
                Text(card.categoryLabel.uppercased())
                    .font(.caption.weight(.black))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.9))

                Text(card.headline)
                    .font(card.presentation == .heroLead ? .system(size: 38, weight: .bold, design: .rounded) : .system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text(card.source.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(24)
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
