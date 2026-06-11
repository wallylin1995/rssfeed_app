import Foundation
import SwiftData

actor RSSSyncService {
    private let parser = RSSFeedParser()

    func fetch(subscription: FeedSource) async throws -> ParsedFeed {
        let data = try await fetchData(from: subscription.url)
        return try parser.parse(data: data)
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Jippo/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
