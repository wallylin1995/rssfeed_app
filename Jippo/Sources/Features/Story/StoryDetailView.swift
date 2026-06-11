import SwiftUI

struct StoryDetailView: View {
    let article: ArticleRecord
    @State private var showingEmbeddedBrowser = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let imageLink = article.imageLink {
                    AsyncImage(url: imageLink) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 280)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 420)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(JippoPalette.panelSoft)
                                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 420)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cardChrome(radius: 34)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(article.sourceTitle)
                        .font(.headline)
                        .foregroundStyle(JippoPalette.highlight)

                    Text(article.title)
                        .font(.system(size: 38, weight: .bold, design: .rounded))

                    HStack(spacing: 10) {
                        Text(article.displayDateText)
                        Text("•")
                        Text(article.displayByline)
                        if let topicLabel = article.topicLabel {
                            Text("•")
                            Text(topicLabel)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                    if let summary = article.content?.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if article.articleLink != nil {
                        Button {
                            showingEmbeddedBrowser = true
                        } label: {
                            Label("Open Original Article", systemImage: "globe")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JippoPalette.highlight)
                    }

                    Divider()
                        .overlay(.white.opacity(0.1))

                    if let text = article.content?.text, !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        Text("This article has not cached its body text yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(JippoPalette.canvas.ignoresSafeArea())
        .navigationTitle(article.sourceTitle)
        .jippoTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEmbeddedBrowser) {
            EmbeddedArticleBrowserView(article: article)
        }
    }
}

struct StoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let feed = FeedRecord(feedURL: "https://example.com", title: "Preview Feed", categoryKey: FeedCategory.world.rawValue)
        let article = ArticleRecord(title: "Preview Story", link: "https://example.com/story", sourceTitle: "Preview Feed", feed: feed)
        article.content = ArticleContentRecord(summary: "Summary", text: "Body text", html: "<p>Body text</p>", article: article)

        return NavigationStack {
            StoryDetailView(article: article)
                .preferredColorScheme(.dark)
        }
    }
}
