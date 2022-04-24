//
//  FeedStore.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import Foundation

public protocol FeedStore {
    
    typealias DataRepresentation = FeedStoreDataRepresentation
    typealias LoadResult = FeedStoreResult
    
    func load(completion: @escaping (Result<FeedStoreResult, Error>) -> Void)
    func save(data: FeedStoreDataRepresentation, completion: @escaping (Result<Void, Error>) -> Void)
    func delete(completion: @escaping (Result<Void, Error>) -> Void)
    
}
