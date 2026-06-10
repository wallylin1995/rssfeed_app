import SwiftUI

struct AppView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView(selection: tabSelection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    rootView(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .background(JippoPalette.canvas.ignoresSafeArea())
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { appModel.selectedTab },
            set: { appModel.selectedTab = $0 }
        )
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .feeds:
            FeedDirectoryView()
        case .saved:
            SavedArticlesView()
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
            .environmentObject(AppModel())
            .preferredColorScheme(.dark)
    }
}
