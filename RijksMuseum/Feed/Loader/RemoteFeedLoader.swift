//
//  RemoteFeedLoader.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import Foundation

public class RemoteFeedLoader: FeedLoader {
    
    struct RemoteFeedRepresentation: Codable, Equatable {
        let count: Int
        let artObjects: [FeedItem]
    }
    
    let session: URLSession
    let url: URL
    
    public init(session: URLSession, url: URL) {
        self.session = session
        self.url = url
    }
    
    public func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse, self.isValid(httpResponse) {
                completion(self.parse(data))
            } else {
                completion(.failure(RemoteFeedLoaderError.invalidResponse))
            }
        }.resume()
    }
    
    private func isValid(_ response: HTTPURLResponse) -> Bool {
        (200..<300).contains(response.statusCode)
    }
    
    private func parse(_ data: Data?) -> Result<[FeedItem], Swift.Error> {
        guard let data = data else {
            return .failure(RemoteFeedLoaderError.invalidResponse)
        }
        do {
            let feed = try JSONDecoder().decode(RemoteFeedRepresentation.self, from: data)
            return .success(feed.artObjects)
        } catch {
            return .failure(RemoteFeedLoaderError.decodeError)
        }
    }
    
    private enum RemoteFeedLoaderError: Error {
        case invalidResponse
        case decodeError
    }
    
}

extension RemoteFeedLoader {
    /// for testing purpose only
    public static func remoteRepresentaionData(for items: [FeedItem]) -> Data? {
        
        let feed = RemoteFeedRepresentation(count: items.count, artObjects: items)
        return try? JSONEncoder().encode(feed)
        
    }
}
