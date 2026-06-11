import Foundation

struct ParsedFeed {
    var title: String
    var siteURL: String?
    var summary: String?
    var items: [ParsedArticle]
}

struct ParsedArticle {
    var remoteID: String?
    var title: String
    var link: String
    var author: String?
    var summary: String?
    var contentHTML: String?
    var publishedAt: Date?
    var imageURL: String?
}

struct RSSFeedParser {
    func parse(data: Data) throws -> ParsedFeed {
        let delegate = RSSXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }

        return delegate.parsedFeed()
    }
}

private final class RSSXMLParserDelegate: NSObject, XMLParserDelegate {
    private var channelTitle = ""
    private var channelLink: String?
    private var channelDescription: String?
    private var items: [ParsedArticle] = []
    private var currentText = ""
    private var currentArticle: ArticleBuilder?
    private var currentElement = ""
    private var currentFeedLinkHref: String?

    func parsedFeed() -> ParsedFeed {
        ParsedFeed(
            title: channelTitle.isEmpty ? "Untitled Feed" : channelTitle,
            siteURL: channelLink,
            summary: channelDescription,
            items: items.filter { !$0.title.isEmpty && !$0.link.isEmpty }
        )
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "item", "entry":
            currentArticle = ArticleBuilder()
        case "link":
            if currentArticle != nil {
                if let href = attributeDict["href"], !href.isEmpty {
                    currentArticle?.link = href
                }
            } else if let href = attributeDict["href"], !href.isEmpty {
                currentFeedLinkHref = href
            }
        case "media:content", "media:thumbnail", "enclosure":
            if let url = attributeDict["url"], currentArticle?.imageURL == nil {
                currentArticle?.imageURL = url
            }
        case "content", "content:encoded", "summary", "description":
            break
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentArticle != nil {
            switch elementName {
            case "title":
                if currentArticle?.title.isEmpty ?? true {
                    currentArticle?.title = trimmed
                }
            case "link":
                if (currentArticle?.link.isEmpty ?? true) && !trimmed.isEmpty {
                    currentArticle?.link = trimmed
                }
            case "guid", "id":
                if currentArticle?.remoteID == nil {
                    currentArticle?.remoteID = trimmed
                }
            case "author", "dc:creator", "name":
                if currentArticle?.author == nil, !trimmed.isEmpty {
                    currentArticle?.author = trimmed
                }
            case "description", "summary":
                if currentArticle?.summary == nil || currentArticle?.summary?.isEmpty == true {
                    currentArticle?.summary = trimmed
                }
                if currentArticle?.contentHTML == nil {
                    currentArticle?.contentHTML = trimmed
                }
            case "content", "content:encoded":
                if !trimmed.isEmpty {
                    currentArticle?.contentHTML = trimmed
                }
            case "pubDate", "published", "updated":
                if currentArticle?.publishedAt == nil {
                    currentArticle?.publishedAt = FeedDateParser.parse(trimmed)
                }
            case "item", "entry":
                if var built = currentArticle?.build() {
                    let html = built.contentHTML ?? built.summary ?? ""
                    if built.imageURL == nil {
                        built.imageURL = HTMLContentExtractor.firstImageURL(in: html)
                    }
                    if built.summary == nil || built.summary?.isEmpty == true {
                        built.summary = HTMLContentExtractor.plainText(from: html)
                    }
                    items.append(built)
                }
                currentArticle = nil
            default:
                break
            }
        } else {
            switch elementName {
            case "title":
                if channelTitle.isEmpty {
                    channelTitle = trimmed
                }
            case "link":
                if channelLink == nil {
                    channelLink = currentFeedLinkHref ?? trimmed
                }
                currentFeedLinkHref = nil
            case "description", "subtitle":
                if channelDescription == nil {
                    channelDescription = trimmed
                }
            default:
                break
            }
        }

        currentText = ""
    }
}

private struct ArticleBuilder {
    var remoteID: String?
    var title = ""
    var link = ""
    var author: String?
    var summary: String?
    var contentHTML: String?
    var publishedAt: Date?
    var imageURL: String?

    func build() -> ParsedArticle {
        ParsedArticle(
            remoteID: remoteID ?? (link.isEmpty ? nil : link),
            title: title,
            link: link,
            author: author,
            summary: summary,
            contentHTML: contentHTML,
            publishedAt: publishedAt,
            imageURL: imageURL
        )
    }
}

enum FeedDateParser {
    static func parse(_ string: String) -> Date? {
        let rfc822 = DateFormatter()
        rfc822.locale = Locale(identifier: "en_US_POSIX")
        rfc822.dateFormat = "E, d MMM yyyy HH:mm:ss Z"

        let rfc822Alt = DateFormatter()
        rfc822Alt.locale = Locale(identifier: "en_US_POSIX")
        rfc822Alt.dateFormat = "E, d MMM yyyy HH:mm Z"

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]

        return rfc822.date(from: string)
            ?? rfc822Alt.date(from: string)
            ?? iso.date(from: string)
            ?? isoPlain.date(from: string)
    }
}

enum HTMLContentExtractor {
    static func firstImageURL(in html: String) -> String? {
        let pattern = #"img[^>]+src=["']([^"']+)["']"#
        return firstMatch(pattern: pattern, in: html)
    }

    static func plainText(from html: String) -> String {
        guard !html.isEmpty else { return "" }

        let blockBreaks = html
            .replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "(?i)</(p|div|section|article|li|ul|ol|h1|h2|h3|h4|h5|h6)>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<script[^>]*>.*?</script>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<style[^>]*>.*?</style>", with: " ", options: .regularExpression)

        let stripped = blockBreaks.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let decoded = decodeHTMLEntities(in: stripped)

        return decoded
            .replacingOccurrences(of: "[\\t\\f\\r ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let resultRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[resultRange])
    }

    private static func decodeHTMLEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
