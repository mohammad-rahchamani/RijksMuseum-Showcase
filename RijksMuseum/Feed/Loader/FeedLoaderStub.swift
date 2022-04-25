//
//  FeedLoaderStub.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation

class FeedLoaderStub: FeedLoader {
    
    private let items: [FeedItem]
    
    init(items: [FeedItem] = [FeedItem(id: "id",
                                       objectNumber: "number",
                                       title: "title",
                                       longTitle: "long title",
                                       webImage: FeedImage(guid: "", url: ""),
                                       headerImage: FeedImage(guid: "", url: ""))]) {
        self.items = items
    }
    
    func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        completion(.success(items))
    }
}
