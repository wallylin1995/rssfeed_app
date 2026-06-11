import SwiftUI
import SwiftData

@main
struct JippoApp: App {
    @StateObject private var appModel = AppModel()
    private let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            FeedRecord.self,
            ArticleRecord.self,
            ArticleContentRecord.self,
            HomepagePlanRecord.self,
            HomepageSectionRecord.self,
            HomepagePlacementRecord.self
        ])

        do {
            sharedModelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create shared model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)

        WindowGroup("Article Reader", id: "article-reader", for: UUID.self) { $articleID in
            ArticleReaderWindowScene(articleID: articleID)
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
        }
#if os(macOS)
        .defaultWindowPlacement { _, context in
            let rect = context.defaultDisplay.visibleRect
            let width = min(1280, rect.width * 0.82)
            let height = min(920, rect.height * 0.86)
            return WindowPlacement(size: CGSize(width: width, height: height))
        }
#endif
        .modelContainer(sharedModelContainer)
    }
}

private struct ArticleReaderWindowScene: View {
    @Environment(\.modelContext) private var modelContext
    let articleID: UUID?

    var body: some View {
        Group {
            if let article = article {
                EmbeddedArticleBrowserView(article: article)
            } else {
                ContentUnavailableView(
                    "Article Unavailable",
                    systemImage: "newspaper",
                    description: Text("The selected article could not be loaded into the reader window.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(JippoPalette.canvas)
            }
        }
    }

    private var article: ArticleRecord? {
        guard let articleID else { return nil }
        var descriptor = FetchDescriptor<ArticleRecord>(predicate: #Predicate { $0.uuid == articleID })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
