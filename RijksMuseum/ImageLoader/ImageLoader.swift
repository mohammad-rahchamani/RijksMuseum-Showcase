//
//  ImageLoader.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation
import UIKit

public class ImageLoader {
    
    private let cache: URLCache
    private let session: URLSession
    
    public init(session: URLSession = .shared, cache: URLCache) {
        self.session = session
        self.cache = cache
    }
    
    public func load(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = session.dataTask(with: url)
        self.cache.getCachedResponse(for: task) { [weak self] response in
            guard let self = self else { return }
            if let response = response {
                completion(.success(response.data))
                return
            }
            self.loadFrom(url, completion: completion)
        }
    }
    
    private func loadFrom(_ url: URL,
                          completion: @escaping (Result<Data, Error>) -> Void) {
        session.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            if let httpResponse = response as? HTTPURLResponse,
               let data = data,
               self.isValid(httpResponse),
               self.isValid(data) {
                self.cache.storeCachedResponse(CachedURLResponse(response: response!,
                                                                 data: data),
                                               for: URLRequest(url: url))
                completion(.success(data))
                return
            }
            completion(.failure(ImageLoaderError.invalidResponse))
        }.resume()
    }
    
    private func isValid(_ data: Data) -> Bool {
        guard let _ = UIImage(data: data) else { return false}
        return true
    }
    
    private func isValid(_ response: HTTPURLResponse) -> Bool {
        (200..<300).contains(response.statusCode)
    }
    
    enum ImageLoaderError: Error {
        case invalidResponse
    }
    
}
