import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case feeds
    case saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Today"
        case .feeds:
            "Feeds"
        case .saved:
            "Saved"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "sparkles.rectangle.stack"
        case .feeds:
            "dot.radiowaves.left.and.right"
        case .saved:
            "bookmark"
        }
    }
}
