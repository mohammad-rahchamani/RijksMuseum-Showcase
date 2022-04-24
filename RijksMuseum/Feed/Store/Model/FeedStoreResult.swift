//
//  FeedStoreResult.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import Foundation

public enum FeedStoreResult: Equatable {
    case empty
    case result(FeedStoreDataRepresentation)
}
