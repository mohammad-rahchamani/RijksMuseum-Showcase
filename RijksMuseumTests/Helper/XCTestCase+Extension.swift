//
//  XCTestCase+Extension.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import XCTest
import RijksMuseum

public extension XCTestCase {
    
    func invalidData() -> Data {
        "invalid data".data(using: .utf8)!
    }
    
    func anyFeedImage() -> FeedImage {
        FeedImage(guid: "guid", url: "url string")
    }
    
    func anyFeedItem() -> FeedItem {
        FeedItem(id: "id",
                 objectNumber: "object number",
                 title: "title",
                 longTitle: "long title",
                 webImage: anyFeedImage(),
                 headerImage: anyFeedImage())
    }
    
    func anyURL() -> URL {
        URL(string: "https://any-url.com")!
    }
    
    func anyNSError() -> NSError {
        NSError(domain: "any error", code: 1, userInfo: nil)
    }
    
    func getData(from data: [FeedItem]) -> Data {
        RemoteFeedLoader.remoteRepresentaionData(for: data)!
    }
}

extension XCTestCase {
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "instance should be nil", file: file, line: line)
        }
    }
}
