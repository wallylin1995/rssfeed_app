import SwiftUI

struct StoryDetailView: View {
    let card: StoryCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StoryArtworkCard(card: card)
                    .frame(height: 360)
                    .cardChrome(radius: 34)

                VStack(alignment: .leading, spacing: 14) {
                    Text(card.source.title)
                        .font(.headline)
                        .foregroundStyle(JippoPalette.highlight)

                    Text(card.headline)
                        .font(.system(size: 38, weight: .bold, design: .rounded))

                    Text(card.summary)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Divider()
                        .overlay(.white.opacity(0.1))

                    Text("Why this section exists")
                        .font(.title2.bold())

                    Text("Jippo’s homepage is meant to feel curated without inventing any article facts. This detail screen is placeholder content for the first scaffold, but its structure already matches the future path: source metadata, article cache, AI annotations, and section placement can all land here cleanly.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(JippoPalette.canvas.ignoresSafeArea())
        .navigationTitle(card.categoryLabel)
        .jippoTitleDisplayMode(.inline)
    }
}

struct StoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StoryDetailView(card: HomepagePlan.sample(feeds: SampleFeedCatalog.fallbackFeeds).sections[0].cards[0])
                .preferredColorScheme(.dark)
        }
    }
}
