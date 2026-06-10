import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HomeHeaderView(
                    title: appModel.homepage.title,
                    subtitle: "Your feeds, laid out like an editorial front page."
                )

                ForEach(appModel.homepage.sections) { section in
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeaderView(title: section.title, subtitle: section.subtitle)

                        switch section.style {
                        case .hero:
                            HeroSectionView(cards: section.cards)
                        case .grid:
                            StoryGridSectionView(cards: section.cards)
                        case .rail:
                            TopicRailSectionView(cards: section.cards)
                        }
                    }
                }

                FeedCategoryOverview(feeds: appModel.feeds)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 1500)
            .frame(maxWidth: .infinity)
        }
        .background(JippoPalette.canvas.ignoresSafeArea())
        .navigationTitle("Jippo")
        .jippoTitleDisplayMode(.large)
    }
}

private struct HomeHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Label("Demo built from your ReadKit OPML feed lineup", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JippoPalette.highlight)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
                .environmentObject(AppModel())
                .preferredColorScheme(.dark)
        }
    }
}
