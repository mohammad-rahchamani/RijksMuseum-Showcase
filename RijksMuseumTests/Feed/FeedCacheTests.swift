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
    
    let store: FeedStore
    let remoteLoader: RemoteFeedLoader
    
    init(store: FeedStore, remoteLoader: RemoteFeedLoader) {
        self.store = store
        self.remoteLoader = remoteLoader
    }
    
    func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        self.store.load { [unowned self] storeResult in
            switch storeResult {
            case .failure:
                removeStoreData {
                    completion(.success([]))
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
                                       completion: @escaping (Result<[FeedItem], Error>) -> Void ) {
        switch result {
        case .empty:
            removeStoreData {
                completion(.success([]))
            }
        case .result(let feedStoreDataRepresentation):
            completion(.success(feedStoreDataRepresentation.feed))
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
        XCTAssertTrue(spy.messages.isEmpty, "expected no messages to feed store, got \(spy.messages) instead.")
    }
    
    func test_load_requestsLoadFromLocalStorage() {
        let (sut, spy) = makeSUT()
        sut.load() { _ in }
        XCTAssertEqual(spy.messages, [.load], "expected load message to feed store, got \(spy.messages) instead.")
    }
    
    func test_load_requestsDeleteOnLoadError() {
        let (sut, spy) = makeSUT()
        sut.load() { _ in }
        spy.completeLoad(withResult: .failure(anyNSError()))
        XCTAssertEqual(spy.messages, [.load, .delete], "expected load and delete message to feed store, got \(spy.messages) instead.")
    }
    
    func test_load_requestsDeleteOnEmptyResultFromStore() {
        let (sut, spy) = makeSUT()
        sut.load() { _ in }
        spy.completeLoad(withResult: .success(.empty))
        XCTAssertEqual(spy.messages, [.load, .delete], "expected load and delete message to feed store, got \(spy.messages) instead.")
    }
    
    // MARK: helpers
    
    func makeSUT(file: StaticString = #file,
                 line: UInt = #line) -> (FeedCache, FeedStoreSpy) {
        let spy = FeedStoreSpy()
        let remoteLoader = RemoteFeedLoader(session: .shared)
        let sut = FeedCache(store: spy, remoteLoader: remoteLoader)
        trackForMemoryLeaks(spy, file: file, line: line)
        trackForMemoryLeaks(remoteLoader, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, spy)
    }

}
