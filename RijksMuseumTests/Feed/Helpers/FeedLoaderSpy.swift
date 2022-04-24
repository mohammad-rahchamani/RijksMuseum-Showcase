//
//  FeedLoaderSpy.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation
import RijksMuseum

class FeedLoaderSpy: FeedLoader {
    
    var completions: [(Result<[FeedItem], Error>) -> Void] = []
    
    func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        completions.append(completion)
    }
    
    func completeLoad(at index: Int = 0, withResult result: Result<[FeedItem], Error>) {
        completions[index](result)
    }
    
}
