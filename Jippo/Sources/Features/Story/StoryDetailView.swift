import SwiftUI

struct StoryDetailView: View {
    @Environment(\.openWindow) private var openWindow
    let article: ArticleRecord
    @StateObject private var intelligence: ArticleIntelligenceViewModel
    @State private var showingEmbeddedBrowser = false

    init(article: ArticleRecord) {
        self.article = article
        _intelligence = StateObject(wrappedValue: ArticleIntelligenceViewModel(article: article))
    }

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
                            #if os(macOS)
                            openWindow(id: "article-reader", value: article.uuid)
                            #else
                            showingEmbeddedBrowser = true
                            #endif
                        } label: {
                            Label("Open Original Article", systemImage: "globe")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JippoPalette.highlight)
                    }

                    intelligencePanel

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
#if !os(macOS)
        .sheet(isPresented: $showingEmbeddedBrowser) {
            EmbeddedArticleBrowserView(article: article)
        }
#endif
    }

    private var intelligencePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Label("Apple Intelligence", systemImage: "apple.intelligence")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                if intelligence.isSummarizing || intelligence.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task { await intelligence.summarize() }
                } label: {
                    Label("Summarize", systemImage: "text.alignleft")
                }
                .buttonStyle(.bordered)
                .disabled(intelligence.isSummarizing || intelligence.isTranslating)

                Button {
                    Task { await intelligence.translateToTraditionalChinese() }
                } label: {
                    Label("繁中", systemImage: "character.book.closed")
                }
                .buttonStyle(.bordered)
                .disabled(intelligence.isSummarizing || intelligence.isTranslating)

                Button {
                    Task { await intelligence.translateToEnglish() }
                } label: {
                    Label("English", systemImage: "globe")
                }
                .buttonStyle(.bordered)
                .disabled(intelligence.isSummarizing || intelligence.isTranslating)

                if intelligence.translation != nil {
                    Button("Reset") {
                        intelligence.clearTranslation()
                    }
                    .buttonStyle(.bordered)
                    .disabled(intelligence.isSummarizing || intelligence.isTranslating)
                }
            }

            if let errorMessage = intelligence.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let summary = intelligence.summary, !summary.isEmpty {
                intelligenceCard(title: "Summary", systemImage: "sparkles", body: summary)
            }

            if let translation = intelligence.translation {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Translation · \(translation.targetLanguageLabel)", systemImage: "text.bubble")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JippoPalette.highlight)

                    Text(translation.translatedTitle)
                        .font(.title3.weight(.bold))

                    if let translatedSummary = translation.translatedSummary, !translatedSummary.isEmpty {
                        Text(translatedSummary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Text(translation.translatedBody)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(18)
                .background(JippoPalette.panel.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(18)
        .background(JippoPalette.panelSoft.opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func intelligenceCard(title: String, systemImage: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JippoPalette.highlight)

            Text(body)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(JippoPalette.panel.opacity(0.88))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
