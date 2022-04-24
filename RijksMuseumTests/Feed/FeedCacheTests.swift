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

class FeedLoaderSpy: FeedLoader {
    
    var completions: [(Result<[FeedItem], Error>) -> Void] = []
    
    func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        completions.append(completion)
    }
    
    func completeLoad(at index: Int = 0, withResult result: Result<[FeedItem], Error>) {
        completions[index](result)
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
        loader.load { [unowned self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let feed):
                self.cache(feed, completion: completion)
            }
        }
    }
    
    private func cache(_ feed: [FeedItem], completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        store.save(data: FeedStore.DataRepresentation(feed: feed,
                                                      timestamp: self.currentDate())) { result in
            completion(.success(feed))
        }
    }
    
}



class FeedCacheTests: XCTestCase {
    
    func test_init_doesNotMessageStoreAndNetwork() {
        let (_, storeSpy, loaderSpy) = makeSUT()
        expect(loaderSpy, loadCallCount: 0)
        expect(storeSpy, toRecieve: [])
    }
    
    func test_load_requestsLoadFromLocalStorage() {
        let (sut, spy, _) = makeSUT()
        sut.load() { _ in }
        expect(spy, toRecieve: [.load])
    }
    
    // MARK: -load requests delete on no valid cache cases
    
    func test_load_requestsDeleteOnLoadError() {
        let (sut, spy, _) = makeSUT()
        sut.load() { _ in }
        spy.completeLoad(withResult: .failure(anyNSError()))
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsDeleteOnEmptyResultFromStore() {
        let (sut, spy, _) = makeSUT()
        sut.load() { _ in }
        spy.completeLoad(withResult: .success(.empty))
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsDeleteOnExpiredCache() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy, _) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        sut.load() { _ in }
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        spy.completeLoad(withResult: .success(.result(data)))
        expect(spy, toRecieve: [.load, .delete])
    }
    
    // MARK: -load requests data from loader on no valid cache cases
    
    func test_load_requestsLoadFromRemoteLoaderOnStoreLoadErrorAndSuccessfulDelete() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(loaderSpy, loadCallCount: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .success(()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnStoreLoadErrorAndFailedDelete() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(loaderSpy, loadCallCount: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnEmptyCacheAndSuccessfulDelete() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(loaderSpy, loadCallCount: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .success(()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnEmptyCacheAndFailedDelete() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(loaderSpy, loadCallCount: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnExpiredCacheAndSuccessfulDelete() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(loaderSpy, loadCallCount: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .success(()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    func test_load_requestsLoadFromRemoteLoaderOnExpiredCacheAndFailedDelete() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(loaderSpy, loadCallCount: 1) {
            sut.load() { _ in }
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .failure(anyNSError()))
        }
        expect(spy, toRecieve: [.load, .delete])
    }
    
    // MARK: -load fails on loader error when called
    
    func test_load_failsOnStoreLoadErrorAndSuccessfulDeleteAndLoaderError() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnStoreLoadErrorAndDeleteErrorAndLoaderError() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnEmptyCacheAndDeleteErrorAndLoaderError() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnEmptyCacheAndSuccessfulDeleteAndLoaderError() {
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnExpiredCacheAndDeleteErrorAndLoaderError() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_failsOnExpiredCacheAndSuccessfulDeleteAndLoaderError() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let data = FeedStoreDataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut,
               toCompleteLoadWith: .failure(anyNSError())) {
            spy.completeLoad(withResult: .success(.result(data)))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .failure(anyNSError()))
        }
    }
    
    // MARK: -load saves data on loader result when called
    
    func test_load_writesToStoreOnStoreLoadErrorAndSuccessfulDeleteAndLoaderResult() {
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let expectedData = FeedStoreDataRepresentation(feed: expectedItems,
                                                     timestamp: fixedCurrentDate)
        let (sut, spy, loaderSpy) = makeSUT(currentDate: { fixedCurrentDate })
        sut.load { _ in }
        spy.completeLoad(withResult: .failure(anyNSError()))
        spy.completeDelete(withResult: .success(()))
        loaderSpy.completeLoad(withResult: .success(expectedItems))
        expect(spy, toRecieve: [.load, .delete, .save(expectedData)])
    }
    
    func test_load_writesToStoreOnStoreLoadErrorAndDeleteErrorAndLoaderResult() {
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let expectedData = FeedStoreDataRepresentation(feed: expectedItems,
                                                     timestamp: fixedCurrentDate)
        let (sut, spy, loaderSpy) = makeSUT(currentDate: { fixedCurrentDate })
        sut.load { _ in }
        spy.completeLoad(withResult: .failure(anyNSError()))
        spy.completeDelete(withResult: .failure(anyNSError()))
        loaderSpy.completeLoad(withResult: .success(expectedItems))
        expect(spy, toRecieve: [.load, .delete, .save(expectedData)])
    }
    
    func test_load_writesToStoreOnEmptyCacheAndDeleteErrorAndLoaderResult() {
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let expectedData = FeedStoreDataRepresentation(feed: expectedItems,
                                                     timestamp: fixedCurrentDate)
        let (sut, spy, loaderSpy) = makeSUT(currentDate: { fixedCurrentDate })
        sut.load { _ in }
        spy.completeLoad(withResult: .success(.empty))
        spy.completeDelete(withResult: .failure(anyNSError()))
        loaderSpy.completeLoad(withResult: .success(expectedItems))
        expect(spy, toRecieve: [.load, .delete, .save(expectedData)])
    }
    
    func test_load_writesToStoreOnEmptyCacheAndSuccessfulDeleteAndLoaderResult() {
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let expectedData = FeedStoreDataRepresentation(feed: expectedItems,
                                                     timestamp: fixedCurrentDate)
        let (sut, spy, loaderSpy) = makeSUT(currentDate: { fixedCurrentDate })
        sut.load { _ in }
        spy.completeLoad(withResult: .success(.empty))
        spy.completeDelete(withResult: .success(()))
        loaderSpy.completeLoad(withResult: .success(expectedItems))
        expect(spy, toRecieve: [.load, .delete, .save(expectedData)])
    }
    
    func test_load_writesToStoreOnExpiredCacheAndDeleteErrorAndLoaderResult() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let expectedData = FeedStoreDataRepresentation(feed: expectedItems,
                                                     timestamp: fixedCurrentDate)
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let expiredData = FeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        sut.load { _ in }
        spy.completeLoad(withResult: .success(.result(expiredData)))
        spy.completeDelete(withResult: .success(()))
        loaderSpy.completeLoad(withResult: .success(expectedItems))
        expect(spy, toRecieve: [.load, .delete, .save(expectedData)])
    }
    
    func test_load_writesToStoreOnExpiredCacheAndSuccessfulDeleteAndLoaderResult() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let expectedData = FeedStoreDataRepresentation(feed: expectedItems,
                                                     timestamp: fixedCurrentDate)
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let expiredData = FeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        sut.load { _ in }
        spy.completeLoad(withResult: .success(.result(expiredData)))
        spy.completeDelete(withResult: .failure(anyNSError()))
        loaderSpy.completeLoad(withResult: .success(expectedItems))
        expect(spy, toRecieve: [.load, .delete, .save(expectedData)])
    }
    
    // MARK: -load delivers data on load result
    
    func test_load_deliversDataOnStoreLoadErrorAndSuccessfulDeleteAndLoaderResultAndWriteError() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_deliversDataOnStoreLoadErrorAndSuccessfulDeleteAndLoaderResultAndSuccessfulWrite() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .success(()))
        }
    }
    
    func test_load_deliversDataOnStoreLoadErrorAndDeleteErrorAndLoaderResultAndWriteError() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_deliversDataOnStoreLoadErrorAndDeleteErrorAndLoaderResultAndSuccessfulWrite() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .failure(anyNSError()))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .success(()))
        }
    }
    
    func test_load_deliversDataOnEmptyCacheAndDeleteErrorAndLoaderResultAndWriteError() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_deliversDataOnEmptyCacheAndDeleteErrorAndLoaderResultAndSuccessfulWrite() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .success(()))
        }
    }
    
    func test_load_deliversDataOnEmptyCacheAndSuccessfulDeleteAndLoaderResultAndWriteError() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_deliversDataOnEmptyCacheAndSuccessfulDeleteAndLoaderResultAndSuccessfulWrite() {
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT()
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.empty))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .success(()))
        }
    }
    
    func test_load_deliversDataOnExpiredCacheAndDeleteErrorAndLoaderResultAndWriteError() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let expiredData = FeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.result(expiredData)))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_deliversDataOnExpiredCacheAndDeleteErrorAndLoaderResultAndSuccessfulWrite() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let expiredData = FeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.result(expiredData)))
            spy.completeDelete(withResult: .failure(anyNSError()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .success(()))
        }
    }
    
    func test_load_deliversDataOnExpiredCacheAndSuccessfulDeleteAndLoaderResultAndWriteError() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let expiredData = FeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.result(expiredData)))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .failure(anyNSError()))
        }
    }
    
    func test_load_deliversDataOnExpiredCacheAndSuccessfulDeleteAndLoaderResultAndSuccessfulWrite() {
        let cacheAge = testCacheMaxAge()
        let fixedCurrentDate = Date()
        let expectedItems = [anyFeedItem()]
        let (sut, spy, loaderSpy) = makeSUT(maxAge: cacheAge, currentDate: { fixedCurrentDate })
        let expiredCacheTimetamp = fixedCurrentDate
            .addingTimeInterval(-cacheAge)
            .addingTimeInterval(-1)
        let expiredData = FeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: expiredCacheTimetamp)
        expect(sut, toCompleteLoadWith: .success(expectedItems)) {
            spy.completeLoad(withResult: .success(.result(expiredData)))
            spy.completeDelete(withResult: .success(()))
            loaderSpy.completeLoad(withResult: .success(expectedItems))
            spy.completeSave(withResult: .success(()))
        }
    }
    
    // MARK: -helpers
    
    func makeSUT(maxAge: TimeInterval = 5*60,
                 currentDate: @escaping () -> Date = Date.init,
                 file: StaticString = #file,
                 line: UInt = #line) -> (FeedCache, FeedStoreSpy, FeedLoaderSpy) {
        let storeSpy = FeedStoreSpy()
        let loaderSpy = FeedLoaderSpy()
        let sut = FeedCache(store: storeSpy,
                            loader: loaderSpy,
                            maxAge: maxAge,
                            currentDate: currentDate)
        trackForMemoryLeaks(storeSpy, file: file, line: line)
        trackForMemoryLeaks(loaderSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, storeSpy, loaderSpy)
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
    
    func expect(_ spy: FeedLoaderSpy,
                loadCallCount expectedCount: Int,
                executing action: () -> () = { },
                file: StaticString = #file,
                line: UInt = #line) {
        action()
        XCTAssertEqual(spy.completions.count,
                       expectedCount,
                       "expected \(expectedCount) calls to load on feed loader, got \(spy.completions.count) instead.",
                       file: file,
                       line: line)
    }
    
    func testCacheMaxAge() -> TimeInterval {
        5 * 60
    }

}
