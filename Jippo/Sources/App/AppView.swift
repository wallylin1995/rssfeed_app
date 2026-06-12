import SwiftUI
import SwiftData

struct AppView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ReaderShellView()
            .background(JippoPalette.canvas.ignoresSafeArea())
            .task {
                await appModel.bootstrapIfNeeded(context: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await appModel.refreshIfStale(context: modelContext)
                }
            }
    }
}
