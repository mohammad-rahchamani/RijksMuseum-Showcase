//
//  RemoteFeedLoaderTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import XCTest
import RijksMuseum

class RemoteFeedLoaderTests: XCTestCase {

    override func setUpWithError() throws {
        URLProtocolStub.startIntercepting()
    }

    override func tearDownWithError() throws {
        URLProtocolStub.stopIntercepting()
    }
    
    func test_init_doesNotRequestNetwork() {
        _ = makeSUT()
        var capturedRequestsCount = 0
        URLProtocolStub.observe { _ in
            capturedRequestsCount += 1
        }
        XCTAssertEqual(capturedRequestsCount, 0, "expected zero requests, got \(capturedRequestsCount) instead.")
    }
    
    func test_load_requestsNetwork() throws {
        var requestCount = 0
        let exp = XCTestExpectation(description: "waiting for network request")
        URLProtocolStub.observe { _ in
            requestCount += 1
            exp.fulfill()
        }
        let sut = makeSUT()
        sut.load { _ in }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(requestCount, 1, "not expecting requests on init. got \(requestCount).")
    }
    
    func test_load_failsOnNoErrorNoResponseAndNoData() throws {
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: nil)
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNetworkError() throws {
        URLProtocolStub.stub(withData: nil, response: nil, error: anyNSError())
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNetworkErrorAndResponse() throws {
        URLProtocolStub.stub(withData: nil,
                             response: httpResponse(withCode: 200),
                             error: anyNSError())
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNetworkErrorAndData() throws {
        URLProtocolStub.stub(withData: Data(),
                             response: nil,
                             error: anyNSError())
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNetworkErrorAndValidResponseAndData() throws {
        URLProtocolStub.stub(withData: getData(from: [anyFeedItem()]),
                             response: httpResponse(withCode: 200),
                             error: anyNSError())
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNonHttpResponse() throws {
        URLProtocolStub.stub(withData: nil,
                             response: anyURLResponse(),
                             error: nil)
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnHttpResponseAndNoData() throws {
        URLProtocolStub.stub(withData: nil,
                             response: httpResponse(withCode: 200),
                             error: nil)
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNonHttpResponseAndValidData() throws {
        let items: [FeedItem] = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        URLProtocolStub.stub(withData: getData(from: items),
                             response: anyURLResponse(),
                             error: nil)
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOn200HttpResponseAndInvalidData() throws {
        URLProtocolStub.stub(withData: invalidData(),
                             response: httpResponse(withCode: 200),
                             error: nil)
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNon200HttpResponseAndValidData() throws {
        let items: [FeedItem] = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        let codes = [0, 199, 300, 400, 500]
        let sut = makeSUT()
        for code in codes {
            URLProtocolStub.stub(withData: getData(from: items),
                                 response: httpResponse(withCode: code),
                                 error: nil)
            expect(sut, toCompleteWithResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnDataWithNoResponse() throws {
        let items: [FeedItem] = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        let sut = makeSUT()
        URLProtocolStub.stub(withData: getData(from: items),
                             response: nil,
                             error: nil)
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_ReturnsDataOnSuccess() throws {
        let items: [FeedItem] = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        let sut = makeSUT()
        URLProtocolStub.stub(withData: getData(from: items),
                             response: httpResponse(withCode: 200),
                             error: nil)
        expect(sut, toCompleteWithResult: .success(items))
    }
    
    func test_load_doesNotCallCompletionAfterLoaderDeallocated() {
        var sut: RemoteFeedLoader? = RemoteFeedLoader(session: .shared, url: anyURL())
        URLProtocolStub.stub(withData: getData(from: [anyFeedItem()]),
                             response: httpResponse(withCode: 200),
                             error: nil)
        sut?.load { _ in
            XCTFail("completion should not be called.")
        }
        sut = nil
    }
    
    // MARK: helpers
    func makeSUT(file: StaticString = #file, line: UInt = #line) -> RemoteFeedLoader {
        let sut = RemoteFeedLoader(session: .shared, url: anyURL())
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    func expect(_ sut: RemoteFeedLoader,
                toCompleteWithResult expectedResult: Result<[FeedItem], Error>,
                file: StaticString = #file,
                line: UInt = #line) {
        let exp = XCTestExpectation(description: "waiting for load result")
        sut.load{ capturedResult in
            switch (capturedResult, expectedResult) {
            case (.success(let capturedData), .success(let expectedData)):
                XCTAssertEqual(capturedData, expectedData, "expected \(expectedData) got \(capturedData).", file: file, line: line)
            case (.failure, .failure):
                ()
            default:
                XCTFail("expected \(expectedResult) got \(capturedResult)", file: file, line: line)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}
