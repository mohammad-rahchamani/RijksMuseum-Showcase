//
//  FeedItem.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import Foundation

public struct FeedItem: Identifiable, Equatable, Hashable, Codable {
    
    public let id: String
    public let objectNumber: String
    public let title: String
    public let longTitle: String
    public let webImage: FeedImage
    public let headerImage: FeedImage
    
    public init(id: String,
                objectNumber: String,
                title: String,
                longTitle: String,
                webImage: FeedImage,
                headerImage: FeedImage) {
        self.id = id
        self.objectNumber = objectNumber
        self.title = title
        self.longTitle = title
        self.webImage = webImage
        self.headerImage = headerImage
    }
}
