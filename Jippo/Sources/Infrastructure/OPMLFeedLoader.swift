import Foundation

struct OPMLFeedLoader: FeedLoading {
    func loadFeeds() -> [FeedSource] {
        guard let url = Bundle.main.url(forResource: "BuiltInRSS", withExtension: "opml"),
              let parser = XMLParser(contentsOf: url) else {
            return SampleFeedCatalog.fallbackFeeds
        }

        let delegate = OPMLParserDelegate()
        parser.delegate = delegate

        if parser.parse() {
            let feeds = delegate.items.compactMap { item -> FeedSource? in
                guard let url = URL(string: item.xmlURL) else {
                    return nil
                }

                return FeedSource(
                    title: item.title,
                    url: url,
                    category: SampleFeedCatalog.category(for: item.title)
                )
            }

            return feeds.isEmpty ? SampleFeedCatalog.fallbackFeeds : feeds
        } else {
            return SampleFeedCatalog.fallbackFeeds
        }
    }
}

private final class OPMLParserDelegate: NSObject, XMLParserDelegate {
    struct Item {
        let title: String
        let xmlURL: String
    }

    private(set) var items: [Item] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard elementName == "outline",
              attributeDict["type"] == "rss",
              let title = attributeDict["title"] ?? attributeDict["text"],
              let xmlURL = attributeDict["xmlUrl"] else {
            return
        }

        items.append(Item(title: title, xmlURL: xmlURL))
    }
}

enum SampleFeedCatalog {
    static let fallbackFeeds: [FeedSource] = [
        FeedSource(title: "Deutsche Welle", url: URL(string: "https://rss.dw.com/xml/rss-en-all")!, category: .world),
        FeedSource(title: "iThome", url: URL(string: "https://www.ithome.com.tw/rss.xml")!, category: .technology),
        FeedSource(title: "MIT Technology Review", url: URL(string: "https://www.technologyreview.com/feed/")!, category: .technology),
        FeedSource(title: "NOEMA", url: URL(string: "https://www.noemamag.com/feed/")!, category: .ideas),
        FeedSource(title: "ProPublica", url: URL(string: "https://www.propublica.org/feeds/propublica/main")!, category: .world),
        FeedSource(title: "Reuters", url: URL(string: "https://news.google.com/rss/search?q=site%3Areuters.com")!, category: .world),
        FeedSource(title: "The Atlantic", url: URL(string: "https://www.theatlantic.com/feed/all/")!, category: .ideas),
        FeedSource(title: "The Guardian - World", url: URL(string: "https://www.theguardian.com/world/rss")!, category: .world),
        FeedSource(title: "The New Yorker", url: URL(string: "https://www.newyorker.com/feed/news")!, category: .ideas),
        FeedSource(title: "The Verge", url: URL(string: "https://www.theverge.com/rss/index.xml")!, category: .technology),
        FeedSource(title: "上下游新聞", url: URL(string: "https://www.newsmarket.com.tw/feed/")!, category: .taiwan),
        FeedSource(title: "公視新聞網", url: URL(string: "https://news.pts.org.tw/xml/newsfeed.xml")!, category: .taiwan),
        FeedSource(title: "泛科學", url: URL(string: "https://pansci.asia/feed")!, category: .science),
        FeedSource(title: "窩窩", url: URL(string: "https://wuo-wuo.com/?format=feed&type=rss")!, category: .science),
        FeedSource(title: "關鍵評論網", url: URL(string: "https://www.thenewslens.com/feed/feedly")!, category: .taiwan)
    ]

    static func category(for title: String) -> FeedCategory {
        switch title {
        case "Deutsche Welle", "Reuters", "The Guardian - World", "ProPublica":
            .world
        case "iThome", "MIT Technology Review", "The Verge":
            .technology
        case "NOEMA", "The Atlantic", "The New Yorker":
            .ideas
        case "上下游新聞", "公視新聞網", "關鍵評論網":
            .taiwan
        case "泛科學", "窩窩":
            .science
        default:
            .world
        }
    }
}
