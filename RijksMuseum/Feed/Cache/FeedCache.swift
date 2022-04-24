//
//  FeedCache.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation

public class FeedCache: FeedLoader {
    
    private let store: FeedStore
    private let loader: FeedLoader
    private let maxAge: TimeInterval
    private let currentDate: () -> Date
    
    public init(store: FeedStore,
                loader: FeedLoader,
                maxAge: TimeInterval,
                currentDate: @escaping () -> Date) {
        self.store = store
        self.loader = loader
        self.maxAge = maxAge
        self.currentDate = currentDate
    }
    
    public func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        self.store.load { [weak self] storeResult in
            guard let self = self else { return }
            switch storeResult {
            case .failure:
                self.loadFromLoader(completion: completion)
            case .success:
                self.handleStoreLoadResult(try! storeResult.get(), completion: completion)
            }
        }
    }
    
    private func handleStoreLoadResult(_ result: FeedStoreResult,
                                       completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        switch result {
        case .empty:
            self.loadFromLoader(completion: completion)
        case .result(let feedStoreDataRepresentation):
            handleCachedFeed(cache: feedStoreDataRepresentation,
                             completion: completion)
        }
    }
    
    private func handleCachedFeed(cache: FeedStore.DataRepresentation,
                                  completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        if isCacheValid(cache: cache) {
            completion(.success(cache.feed))
        } else {
            self.loadFromLoader(completion: completion)
        }
    }
    
    private func isCacheValid(cache: FeedStore.DataRepresentation) -> Bool {
        currentDate().timeIntervalSince(cache.timestamp) <= maxAge
    }
    
    private func loadFromLoader(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        loader.load { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let feed):
                self.cache(feed, completion: completion)
            }
        }
    }
    
    private func cache(_ feed: [FeedItem], completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        store.save(data: FeedStore.DataRepresentation(feed: feed,
                                                      timestamp: self.currentDate())) { [weak self] result in
            guard let _ = self else { return }
            completion(.success(feed))
        }
    }
    
}
