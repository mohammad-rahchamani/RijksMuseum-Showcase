//
//  LocalFeedStoreTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import XCTest
import RijksMuseum

class LocalFeedStore {
    
    struct DataRepresentation: Equatable, Codable {
        let feed: [FeedItem]
        let timestamp: Date
    }
    
    enum LoadResult: Equatable {
        case empty
        case result(DataRepresentation)
    }
    
    private let storeURL: URL
    
    init(storeURL: URL) {
        self.storeURL = storeURL
        self.setupStore()
    }
    
    private func setupStore() {
        guard !FileManager.default.fileExists(atPath: storeURL.path) else { return }
        try? "".data(using: .utf8)?.write(to: storeURL)
    }
    
    func load(completion: @escaping (Result<LoadResult, Error>) -> Void) {
        
        do {
            let data = try Data(contentsOf: storeURL)
            guard !data.isEmpty else {
                completion(.success(.empty))
                return
            }
            let decoder = JSONDecoder()
            let parsedData = try decoder.decode(DataRepresentation.self, from: data)
            completion(.success(.result(parsedData)))
        } catch {
            completion(.failure(error))
        }
        
        
    }
    
    func save(data: DataRepresentation,
              completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(data)
            try encodedData.write(to: storeURL)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    func delete(completion: @escaping (Result<Void, Error>) -> Void) {
        
    }
    
    
}

class LocalFeedStoreTests: XCTestCase {

    override func setUpWithError() throws {
        removeStoreFile()
    }

    override func tearDownWithError() throws {
        removeStoreFile()
    }
    
    func test_init_createsFileForStore() {
        let _ = makeSUT(storeURL: storeURLForTest())
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURLForTest().path), "expected a file at store path: \(storeURLForTest().path).")
    }
    
    func test_load_returnsEmptyInitially() {
        let sut = LocalFeedStore(storeURL: storeURLForTest())
        expect(sut, toCompleteLoadWith: .success(.empty))
    }
    
    func test_load_hasNoSideEffectsOnEmptyStore() {
        let sut = makeSUT(storeURL: storeURLForTest())
        expect(sut, toCompleteLoadWith: .success(.empty))
        expect(sut, toCompleteLoadWith: .success(.empty))
    }
    
    func test_load_returnsErrorOnStoreError() {
        let sut = makeSUT(storeURL: invalidStoreURL())
        expect(sut, toCompleteLoadWith: .failure(anyNSError()))
    }
    
    func test_load_hasNoSideEffectsOnStoreError() {
        let sut = makeSUT(storeURL: invalidStoreURL())
        expect(sut, toCompleteLoadWith: .failure(anyNSError()))
        expect(sut, toCompleteLoadWith: .failure(anyNSError()))
    }
    
    func test_load_deliversDataFromStore() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let feed = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        let timestamp = Date()
        let expectedResult = LocalFeedStore.DataRepresentation(feed: feed, timestamp: timestamp)
        save(expectedResult, to: sut)
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
    }
    
    func test_load_hasNoSideEffectsOnStoreWithData() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let feed = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        let timestamp = Date()
        let expectedResult = LocalFeedStore.DataRepresentation(feed: feed, timestamp: timestamp)
        save(expectedResult, to: sut)
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
    }
    
    func test_save_completesSuccessfullyOnValidDataAndValidStoreURL() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let feed = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        let timestamp = Date()
        let expectedResult = LocalFeedStore.DataRepresentation(feed: feed, timestamp: timestamp)
        expect(sut,
               toSave: expectedResult,
               andCompleteSaveWith: .success(()))
    }
    
    func test_save_writesDataToStore() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let feed = [anyFeedItem(), anyFeedItem(), anyFeedItem()]
        let timestamp = Date()
        let expectedResult = LocalFeedStore.DataRepresentation(feed: feed, timestamp: timestamp)
        save(expectedResult, to: sut)
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
    }
    
    func test_save_overridesDataOnStoreWithValue() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let sampleData = LocalFeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: Date())
        let expectedResult = LocalFeedStore.DataRepresentation(feed: [anyFeedItem(), anyFeedItem()],
                                                               timestamp: Date())
        save(sampleData, to: sut)
        save(expectedResult, to: sut)
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
    }
    
    func test_save_failsOnStoreError() {
        let sut = makeSUT(storeURL: invalidStoreURL())
        let data = LocalFeedStore.DataRepresentation(feed: [anyFeedItem(), anyFeedItem()],
                                                     timestamp: Date())
        expect(sut, toSave: data, andCompleteSaveWith: .failure(anyNSError()))
    }
    
    // MARK: helpers
    
    func makeSUT(storeURL: URL, file: StaticString = #file, line: UInt = #line) -> LocalFeedStore {
        let sut = LocalFeedStore(storeURL: storeURL)
        addTeardownBlock { [weak sut] in
            XCTAssertNil(sut, "sut should be deallocated", file: file, line: line)
        }
        return sut
    }
    
    func expect(_ sut: LocalFeedStore,
                toCompleteLoadWith expectedResult: Result<LocalFeedStore.LoadResult, Error>,
                file: StaticString = #file,
                line: UInt = #line) {
        let exp = XCTestExpectation(description: "waiting for load completion")
        sut.load { capturedResult in
            switch (capturedResult, expectedResult) {
            case (.failure, .failure):
                ()
            case (.success(let capturedValue),.success(let expectedValue)):
                XCTAssertEqual(capturedValue, expectedValue, file: file, line: line)
            default:
                XCTFail("expected \(expectedResult) got \(capturedResult) instead.", file: file, line: line)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    func expect(_ sut: LocalFeedStore,
                toSave data: LocalFeedStore.DataRepresentation,
                andCompleteSaveWith expectedResult: Result<Void, Error>,
                file: StaticString = #file,
                line: UInt = #line) {
        let exp = XCTestExpectation(description: "waiting for save completion")
        sut.save(data: data) { capturedResult in
            switch (capturedResult, expectedResult) {
            case (.failure, .failure):
                ()
            case (.success, .success):
                ()
            default:
                XCTFail("expected \(expectedResult), got \(capturedResult) instead.", file: file, line: line)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    func save(_ data: LocalFeedStore.DataRepresentation, to store: LocalFeedStore) {
        store.save(data: data) { _ in }
    }
    
    func storeURLForTest() -> URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("\(type(of: self)).store")
    }
    
    func invalidStoreURL() -> URL {
        anyURL()
    }
    
    func removeStoreFile() {
        try? FileManager.default.removeItem(at: storeURLForTest())
    }

}
