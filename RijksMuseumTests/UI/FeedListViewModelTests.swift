//
//  FeedListViewModelTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import XCTest
@testable import RijksMuseum

class FeedListViewModelTests: XCTestCase {

    func test_init_doesNotRequestLoad() {
        let (_, spy) = makeSUT()
        XCTAssertTrue(spy.completions.isEmpty, "expected to message to loader")
    }
    
    func test_load_setsIsLoadingToTrue() {
        let (sut, _) = makeSUT()
        sut.load()
        XCTAssertTrue(sut.isLoading, "expected loading state")
        XCTAssertFalse(sut.loadFailed, "not expecting failure")
    }
    
    func test_load_setsIsLoadingToFalseOnCompletionWithEmptyFeed() {
        let (sut, spy) = makeSUT()
        sut.load()
        spy.completeLoad(withResult: .success([]))
        XCTAssertFalse(sut.isLoading, "expected loaded state")
        XCTAssertFalse(sut.loadFailed, "not expecting failure")
        XCTAssertTrue(sut.feed.isEmpty, "expected empty feed")
    }
    
    func test_load_setsIsLoadingToFalseOnLoadFailure() {
        let (sut, spy) = makeSUT()
        sut.load()
        spy.completeLoad(withResult: .failure(anyNSError()))
        XCTAssertFalse(sut.isLoading, "expected loaded state")
        XCTAssertTrue(sut.loadFailed, "not expecting failure")
    }
    
    func test_load_setsFeedOnResult() {
        let (sut, spy) = makeSUT()
        sut.load()
        let expectedFeed = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        spy.completeLoad(withResult: .success(expectedFeed))
        XCTAssertFalse(sut.isLoading, "expected loaded state")
        XCTAssertFalse(sut.loadFailed, "not expecting failure")
        XCTAssertEqual(sut.feed, expectedFeed, "expected \(expectedFeed) got \(sut.feed) instead.")
    }
    
    // MARK: - helpers
    
    func makeSUT(file: StaticString = #file, line: UInt = #line) -> (FeedListViewModel, FeedLoaderSpy) {
        let spy = FeedLoaderSpy()
        let sut = FeedListViewModel(loader: spy)
        trackForMemoryLeaks(spy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, spy)
    }

}
