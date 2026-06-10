import Foundation

struct FeedSource: Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: URL
    let category: FeedCategory

    init(id: UUID = UUID(), title: String, url: URL, category: FeedCategory) {
        self.id = id
        self.title = title
        self.url = url
        self.category = category
    }
}

enum FeedCategory: String, CaseIterable, Hashable {
    case world
    case technology
    case ideas
    case taiwan
    case science

    var title: String {
        switch self {
        case .world:
            "World"
        case .technology:
            "Technology"
        case .ideas:
            "Ideas"
        case .taiwan:
            "Taiwan"
        case .science:
            "Science"
        }
    }

    var shortLabel: String {
        switch self {
        case .world:
            "世界"
        case .technology:
            "科技"
        case .ideas:
            "觀點"
        case .taiwan:
            "台灣"
        case .science:
            "科學"
        }
    }
}
