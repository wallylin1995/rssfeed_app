import SwiftUI

struct SavedArticlesView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Saved Articles", systemImage: "bookmark")
        } description: {
            Text("This tab is ready for the next step: syncing read, starred, and offline states from your future local database.")
        } actions: {
            Text("Next up: hook this screen to `article`, `article_content`, and offline state.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Saved")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(JippoPalette.canvas)
    }
}

struct SavedArticlesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SavedArticlesView()
                .preferredColorScheme(.dark)
        }
    }
}
