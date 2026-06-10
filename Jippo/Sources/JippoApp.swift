import SwiftUI

@main
struct JippoApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
        }
    }
}
