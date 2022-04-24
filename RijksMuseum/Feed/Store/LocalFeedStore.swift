//
//  LocalFeedStore.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import Foundation

public class LocalFeedStore {
    
    public struct DataRepresentation: Equatable, Codable {
        let feed: [FeedItem]
        let timestamp: Date
        
        public init(feed: [FeedItem], timestamp: Date) {
            self.feed = feed
            self.timestamp = timestamp
        }
    }
    
    public enum LoadResult: Equatable {
        case empty
        case result(DataRepresentation)
    }
    
    private let storeURL: URL
    private let queue = DispatchQueue(label: "\(type(of: LocalFeedStore.self))",
                                      qos: .background,
                                      attributes: .concurrent)
    
    public init(storeURL: URL) {
        self.storeURL = storeURL
        self.setupStore()
    }
    
    private func setupStore() {
        guard !FileManager.default.fileExists(atPath: storeURL.path) else { return }
        try? "".data(using: .utf8)?.write(to: storeURL)
    }
    
    public func load(completion: @escaping (Result<LoadResult, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: self.storeURL)
                guard !data.isEmpty else {
                    completion(.success(.empty))
                    return
                }
                let decoder = JSONDecoder()
                let parsedData = try decoder.decode(DataRepresentation.self, from: data)
                completion(.success(.result(parsedData)))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public func save(data: DataRepresentation,
                     completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            do {
                let encoder = JSONEncoder()
                let encodedData = try encoder.encode(data)
                try encodedData.write(to: self.storeURL)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public func delete(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            do {
                try Data().write(to: self.storeURL)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    
}
