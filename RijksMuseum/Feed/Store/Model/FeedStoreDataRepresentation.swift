//
//  FeedStoreDataRepresentation.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import Foundation

public struct FeedStoreDataRepresentation: Equatable, Codable {
    public let feed: [FeedItem]
    public let timestamp: Date
    
    public init(feed: [FeedItem], timestamp: Date) {
        self.feed = feed
        self.timestamp = timestamp
    }
}
