//
//  FeedCacheTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import XCTest
import RijksMuseum

class FeedStoreSpy: FeedStore {
    
    private(set) var messages: [Message] = []
    
    private var loadCompletions: [(Result<FeedStoreResult, Error>) -> Void] = []
    private var saveCompletions: [(Result<Void, Error>) -> Void] = []
    private var deleteCompletions: [(Result<Void, Error>) -> Void] = []
    
    enum Message: Equatable {
        case load
        case save(FeedStoreDataRepresentation)
        case delete
    }
    
    func resetMessages() {
        messages.removeAll()
    }
    
    func completeLoad(at index: Int = 0,
                      withResult result: Result<FeedStoreResult, Error>) {
        loadCompletions[index](result)
    }
    
    func completeSave(at index: Int = 0,
                      withResult result: Result<Void, Error>) {
        saveCompletions[index](result)
    }
    
    func completeDelete(at index: Int = 0,
                        withResult result: Result<Void, Error>) {
        deleteCompletions[index](result)
    }
    
    func load(completion: @escaping (Result<FeedStoreResult, Error>) -> Void) {
        messages.append(.load)
        loadCompletions.append(completion)
    }
    
    func save(data: FeedStoreDataRepresentation, completion: @escaping (Result<Void, Error>) -> Void) {
        messages.append(.save(data))
        saveCompletions.append(completion)
    }
    
    func delete(completion: @escaping (Result<Void, Error>) -> Void) {
        messages.append(.delete)
        deleteCompletions.append(completion)
    }
    
    deinit {
        loadCompletions = []
        saveCompletions = []
        deleteCompletions = []
        messages = []
    }
    
}

class FeedCache {
    
    private let store: FeedStore
    private let loader: FeedLoader
    private let maxAge: TimeInterval
    private let currentDate: () -> Date
    
    init(store: FeedStore,
         loader: FeedLoader,
         maxAge: TimeInterval,
         currentDate: @escaping () -> Date) {
        self.store = store
        self.loader = loader
        self.maxAge = maxAge
        self.currentDate = currentDate
    }
    
    func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        self.store.load { [unowned self] storeResult in
            switch storeResult {
            case .failure:
                removeStoreData {
                    loadFromLoader(completion: completion)
                }
            case .success:
                self.handleStoreLoadResult(try! storeResult.get(), completion: completion)
            }
        }
    }
    
    private func removeStoreData(then closure: @escaping () -> Void) {
        self.store.delete { _ in
            closure()
        }
    }
    
    private func handleStoreLoadResult(_ result: FeedStoreResult,
                                       completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        switch result {
        case .empty:
            removeStoreData { [unowned self] in
                self.loadFromLoader(completion: completion)
            }
        case .result(let feedStoreDataRepresentation):
            handleCachedFeed(cache: feedStoreDataRepresentation,
                             completion: completion)
        }
    }
    
    private func handleCachedFeed(cache: FeedStore.DataRepresentation,
                                  completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        if isCacheValid(cache: cache) {
            completion(.success(cache.feed))
        } else {
            removeStoreData { [unowned self] in
                self.loadFromLoader(completion: completion)
            }
        }
    }
    
    private func isCacheValid(cache: FeedStore.DataRepresentation) -> Bool {
        currentDate().timeIntervalSince(cache.timestamp) <= maxAge
    }
    
    private func loadFromLoader(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        loader.load { result in
            completion(result)
        }
    }
    
}



class FeedCacheTests: XCTestCase {

    override func setUpWithError() throws {
        URLProtocolStub.startIntercepting()
    }

    override func tearDownWithError() throws {
        URLProtocolStub.stopIntercepting()
    }
    
    func test_init_doesNotMessageStoreAndNetwork() {
        var networkCallCount = 0
        URLProtocolStub.observe { _ in
            networkCallCount += 1
        }
        let (_, spy) = makeSUT()
        XCTAssertEqual(networkCallCount, 0, "expected 0 network calls, got \(networkCallCount) instead.")
        expect(spy, toRecieve: [])
    }
    
    func test_load_requestsLoadFromLocalStorage() {
        let (sut, spy) = makeSUT()
        sut.load() { _ in }
        expect(spy, toRecieve: [.load])
    }
    
    func test_load_requestsDeleteOnLoadError() {
        let (sut, spy) = makeSUT()
        sut.load() { _ in }
        spy.completeLoad(withResult: .failure(anyNSError()))
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsDeleteOnEmptyResultFromStore() {
        let (sut, spy) = makeSUT()
        sut.load() { _ in }
        spy.completeLoad(withResult: .success(.empty))
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsDeleteOnExpiredCache() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        sut.load() { _ in }
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        spy.completeLoad(withResult: .success(.result(data)))
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnStoreLoadErrorAndSuccessfulDelete() {
        let (sut, spy) = makeSUT()
        expect(networkCallCounts: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .success(()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnStoreLoadErrorAndFailedDelete() {
        let (sut, spy) = makeSUT()
        expect(networkCallCounts: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnEmptyCacheAndSuccessfulDelete() {
        let (sut, spy) = makeSUT()
        expect(networkCallCounts: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .success(()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnEmptyCacheAndFailedDelete() {
        let (sut, spy) = makeSUT()
        expect(networkCallCounts: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnExpiredCacheAndSuccessfulDelete() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(networkCallCounts: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .success(()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnExpiredCacheAndFailedDelete() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(networkCallCounts: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_failsOnStoreLoadErrorAndSuccessfulDeleteAndLoaderError() {
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: anyNSError())
        let (sut, spy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .success(()))
        }
    }
    
    func test_load_failsOnStoreLoadErrorAndDeleteErrorAndLoaderError() {
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: anyNSError())
        let (sut, spy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnEmptyCacheAndDeleteErrorAndLoaderError() {
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: anyNSError())
        let (sut, spy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnEmptyCacheAndSuccessfulDeleteAndLoaderError() {
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: anyNSError())
        let (sut, spy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .success(()))
        }
    }
    
    func test_load_failsOnExpiredCacheAndDeleteErrorAndLoaderError() {
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: anyNSError())
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnExpiredCacheAndSuccessfulDeleteAndLoaderError() {
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: anyNSError())
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .success(()))
        }
    }
    
    // MARK: helpers
    
    func makeSUT(maxAge: TimeInterval = 5*60,
                 currentDate: @escaping () -> Date = Date.init,
                 file: StaticString = #file,
                 line: UInt = #line) -> (FeedCache, FeedStoreSpy) {
        let spy = FeedStoreSpy()
        let remoteLoader = RemoteFeedLoader(session: .shared, url: anyURL())
        let sut = FeedCache(store: spy,
                            loader: remoteLoader,
                            maxAge: maxAge,
                            currentDate: currentDate)
        trackForMemoryLeaks(spy, file: file, line: line)
        trackForMemoryLeaks(remoteLoader, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, spy)
    }
    
    func expect(_ sut: FeedCache,
                toCompleteLoadWith expectedResult: Result<[FeedItem], Error>,
                executing action: () -> (),
                file: StaticString = #file,
                line: UInt = #line) {
        let exp = XCTestExpectation(description: "waiting for load completion")
        var capturedResult: [Result<[FeedItem], Error>] = []
        sut.load { loadResult in
            capturedResult.append(loadResult)
            exp.fulfill()
        }
        action()
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(capturedResult.count,
                       1,
                       "expected completion to be called once.",
                       file: file,
                       line: line)
        switch (capturedResult.first!, expectedResult) {
        case (.failure, .failure):
            ()
        case (.success(let capturedItems), .success(let expectedItems)):
            XCTAssertEqual(capturedItems,
                           expectedItems,
                           "expected \(expectedItems), got \(capturedItems) instead.",
                           file: file,
                           line: line)
        default:
            XCTFail("expected \(expectedResult), got \(capturedResult.first!) instead",
                    file: file,
                    line: line)
        }
    }
    
    func expect(networkCallCounts expectedNetworkCallCount: Int,
                executing action: () -> (),
                file: StaticString = #file,
                line: UInt = #line) {
        var networkCallCount = 0
        let exp = XCTestExpectation(description: "waiting for network request.")
        URLProtocolStub.observe { _ in
            networkCallCount += 1
            exp.fulfill()
        }
        action()
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(networkCallCount,
                       expectedNetworkCallCount,
                       "expected \(expectedNetworkCallCount) network calls, got \(networkCallCount) instead.",
                       file: file,
                       line: line)
    }
    
    func expect(_ spy: FeedStoreSpy,
                toRecieve expectedMessages: [FeedStoreSpy.Message],
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(spy.messages,
                       expectedMessages,
                       "expected load message to feed store, got \(spy.messages) instead.",
                       file: file,
                       line: line)
    }
    
    func testCacheMaxAge() -> TimeInterval {
        5 * 60
    }

}
