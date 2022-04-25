//
//  FeedImage.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import Foundation

public struct FeedImage: Equatable, Hashable, Codable {
    public let guid: String
    public let url: String
    
    public init(guid: String, url: String) {
        self.guid = guid
        self.url = url
    }
}
