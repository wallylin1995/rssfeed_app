import SwiftUI
import SwiftData

@main
struct JippoApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            FeedRecord.self,
            ArticleRecord.self,
            ArticleContentRecord.self,
            HomepagePlanRecord.self,
            HomepageSectionRecord.self,
            HomepagePlacementRecord.self
        ])
    }
}
