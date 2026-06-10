import SwiftUI

struct FeedDirectoryView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List {
            Section("Imported from OPML") {
                ForEach(appModel.feeds) { feed in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(feed.title)
                                .font(.headline)
                            Spacer()
                            Text(feed.category.shortLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JippoPalette.highlight)
                        }

                        Text(feed.url.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(JippoPalette.canvas)
        .navigationTitle("Feeds")
    }
}

struct FeedDirectoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FeedDirectoryView()
                .environmentObject(AppModel())
                .preferredColorScheme(.dark)
        }
    }
}
