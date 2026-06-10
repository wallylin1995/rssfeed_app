import SwiftUI

struct HomepagePlan: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let sections: [HomepageSection]

    static func sample(feeds: [FeedSource]) -> HomepagePlan {
        let lookup = Dictionary(uniqueKeysWithValues: feeds.map { ($0.title, $0) })

        let topStories = [
            StoryCard(
                source: lookup["Reuters"] ?? .fallback(title: "Reuters", category: .world),
                categoryLabel: "速報",
                headline: "Jippo 把大字報首頁當成 AI 編排問題，而不是另一種靜態清單",
                summary: "第一版首頁以主從層級、雜誌式留白與明確來源品牌為核心，模擬你真正會拿來每天打開的首頁感受。",
                byline: "AI layout rehearsal",
                timeLabel: "Just now",
                accent: .sunset,
                presentation: .heroLead
            ),
            StoryCard(
                source: lookup["The Verge"] ?? .fallback(title: "The Verge", category: .technology),
                categoryLabel: "AI 工具",
                headline: "今天首頁先聚焦最值得打開的兩到三篇，而不是把 50 篇文章平鋪",
                summary: "AI 只負責在既有文章裡選卡、排版、命名 section，維持 RSS 的真實來源與可追溯性。",
                byline: "Foundation Models friendly",
                timeLabel: "6 min read",
                accent: .electric,
                presentation: .heroSupport
            )
        ]

        let magazineGrid = [
            StoryCard(
                source: lookup["Deutsche Welle"] ?? .fallback(title: "Deutsche Welle", category: .world),
                categoryLabel: "Top Stories",
                headline: "跨平台閱讀器不該只複製 Apple News，而是借它的節奏感",
                summary: "首頁改成雜誌式卡片後，新聞的重要性、主題氛圍與來源可信度會同時變得更清楚。",
                byline: "Daily briefing",
                timeLabel: "4m ago",
                accent: .currant,
                presentation: .feature
            ),
            StoryCard(
                source: lookup["上下游新聞"] ?? .fallback(title: "上下游新聞", category: .taiwan),
                categoryLabel: "農業",
                headline: "你自己的 feed 清單也能被 AI 自動拼成主題首頁，例如農業、食安與地方議題",
                summary: "示範資料已經直接接到你的 OPML，未來再換成真正文章資料庫時就能沿用同一個 layout 模型。",
                byline: "Signal over noise",
                timeLabel: "12m ago",
                accent: .forest,
                presentation: .feature
            ),
            StoryCard(
                source: lookup["MIT Technology Review"] ?? .fallback(title: "MIT Technology Review", category: .technology),
                categoryLabel: "AI 工具",
                headline: "首頁規劃只吃文章卡摘要，不吃全文，替未來 on-device AI 留下預算",
                summary: "這讓 Jippo 的策展流程更快，也更符合你前面定下的資料治理規則。",
                byline: "Budgeted context",
                timeLabel: "18m ago",
                accent: .ice,
                presentation: .compact
            ),
            StoryCard(
                source: lookup["公視新聞網"] ?? .fallback(title: "公視新聞網", category: .taiwan),
                categoryLabel: "台灣",
                headline: "在地媒體會跟國際來源一起出現在同一塊首頁，但仍保有各自的品牌識別",
                summary: "這能讓 Jippo 同時像閱讀器，也像一份屬於你自己的晨間報紙。",
                byline: "Mixed feed curation",
                timeLabel: "24m ago",
                accent: .berry,
                presentation: .compact
            )
        ]

        let topicRows = [
            StoryCard(
                source: lookup["關鍵評論網"] ?? .fallback(title: "關鍵評論網", category: .taiwan),
                categoryLabel: "觀點",
                headline: "把重要討論收進觀點主題列，首頁就不只是在追新聞",
                summary: "Topic rails 適合把慢新聞、評論、專題跟硬新聞自然混排。",
                byline: "Editors' note",
                timeLabel: "32m ago",
                accent: .plum,
                presentation: .rail
            ),
            StoryCard(
                source: lookup["泛科學"] ?? .fallback(title: "泛科學", category: .science),
                categoryLabel: "科學",
                headline: "科學與生活類主題可以做成更輕巧的橫向卡片，降低首頁壓迫感",
                summary: "這種 section 特別適合 iPhone 與 visionOS 的延伸呈現。",
                byline: "Topic normalization",
                timeLabel: "45m ago",
                accent: .mint,
                presentation: .rail
            ),
            StoryCard(
                source: lookup["NOEMA"] ?? .fallback(title: "NOEMA", category: .ideas),
                categoryLabel: "Ideas",
                headline: "Jippo 不只是 RSS 收納器，也可以是思考密度很高的閱讀入口",
                summary: "首頁中的 ideas 區會讓整體氣質從資訊流轉向策展閱讀。",
                byline: "Long-form bias",
                timeLabel: "1h ago",
                accent: .amber,
                presentation: .rail
            )
        ]

        return HomepagePlan(
            id: UUID(),
            title: "Jippo",
            subtitle: "AI-driven editorial homepage powered by your own feeds.",
            sections: [
                HomepageSection(title: "Editors’ Pick", subtitle: "A hero layout that feels native on macOS, iPadOS, iOS, and visionOS.", style: .hero, cards: topStories),
                HomepageSection(title: "Top Stories", subtitle: "Magazine cards generated from your OPML feed lineup.", style: .grid, cards: magazineGrid),
                HomepageSection(title: "Topic Rails", subtitle: "Lighter rows for AI-generated sections like 農業, 科學, and Ideas.", style: .rail, cards: topicRows)
            ]
        )
    }
}

struct HomepageSection: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let style: HomepageSectionStyle
    let cards: [StoryCard]

    init(id: UUID = UUID(), title: String, subtitle: String, style: HomepageSectionStyle, cards: [StoryCard]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.cards = cards
    }
}

enum HomepageSectionStyle {
    case hero
    case grid
    case rail
}

struct StoryCard: Identifiable, Hashable {
    let id: UUID
    let source: FeedSource
    let categoryLabel: String
    let headline: String
    let summary: String
    let byline: String
    let timeLabel: String
    let accent: StoryAccent
    let presentation: StoryPresentation

    init(
        id: UUID = UUID(),
        source: FeedSource,
        categoryLabel: String,
        headline: String,
        summary: String,
        byline: String,
        timeLabel: String,
        accent: StoryAccent,
        presentation: StoryPresentation
    ) {
        self.id = id
        self.source = source
        self.categoryLabel = categoryLabel
        self.headline = headline
        self.summary = summary
        self.byline = byline
        self.timeLabel = timeLabel
        self.accent = accent
        self.presentation = presentation
    }
}

enum StoryPresentation: Hashable {
    case heroLead
    case heroSupport
    case feature
    case compact
    case rail
}

enum StoryAccent: Hashable {
    case sunset
    case electric
    case forest
    case currant
    case ice
    case berry
    case plum
    case mint
    case amber

    var colors: [Color] {
        switch self {
        case .sunset:
            [Color(red: 0.93, green: 0.80, blue: 0.37), Color(red: 0.78, green: 0.39, blue: 0.22)]
        case .electric:
            [Color(red: 0.25, green: 0.48, blue: 0.94), Color(red: 0.08, green: 0.14, blue: 0.43)]
        case .forest:
            [Color(red: 0.47, green: 0.72, blue: 0.38), Color(red: 0.15, green: 0.32, blue: 0.15)]
        case .currant:
            [Color(red: 0.96, green: 0.33, blue: 0.45), Color(red: 0.35, green: 0.09, blue: 0.16)]
        case .ice:
            [Color(red: 0.75, green: 0.89, blue: 0.97), Color(red: 0.35, green: 0.48, blue: 0.69)]
        case .berry:
            [Color(red: 0.82, green: 0.35, blue: 0.49), Color(red: 0.38, green: 0.14, blue: 0.29)]
        case .plum:
            [Color(red: 0.71, green: 0.53, blue: 0.92), Color(red: 0.27, green: 0.17, blue: 0.43)]
        case .mint:
            [Color(red: 0.62, green: 0.90, blue: 0.80), Color(red: 0.16, green: 0.42, blue: 0.35)]
        case .amber:
            [Color(red: 0.98, green: 0.72, blue: 0.31), Color(red: 0.54, green: 0.28, blue: 0.11)]
        }
    }

    var symbol: String {
        switch self {
        case .sunset:
            "sun.max.fill"
        case .electric:
            "bolt.fill"
        case .forest:
            "leaf.fill"
        case .currant:
            "newspaper.fill"
        case .ice:
            "aqi.medium"
        case .berry:
            "dot.radiowaves.left.and.right"
        case .plum:
            "text.book.closed.fill"
        case .mint:
            "sparkles"
        case .amber:
            "lightbulb.max.fill"
        }
    }
}

extension FeedSource {
    static func fallback(title: String, category: FeedCategory) -> FeedSource {
        FeedSource(
            title: title,
            url: URL(string: "https://example.com/\(title.replacingOccurrences(of: " ", with: "-").lowercased())")!,
            category: category
        )
    }
}
