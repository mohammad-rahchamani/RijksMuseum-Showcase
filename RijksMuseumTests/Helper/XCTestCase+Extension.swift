//
//  XCTestCase+Extension.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import XCTest
import UIKit
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
    
    func anyURLResponse() -> URLResponse {
        URLResponse(url: anyURL(),
                    mimeType: nil,
                    expectedContentLength: 0,
                    textEncodingName: nil)
    }
    
    func httpResponse(withCode code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(),
                        statusCode: code,
                        httpVersion: nil,
                        headerFields: nil)!
    }
    
    func anyUIImage() -> UIImage {
        UIImage(systemName: "trash")!
    }
}

extension XCTestCase {
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "instance should be nil", file: file, line: line)
        }
    }
}
