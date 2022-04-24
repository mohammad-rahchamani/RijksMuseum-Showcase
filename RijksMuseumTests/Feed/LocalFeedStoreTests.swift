//
//  LocalFeedStoreTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import XCTest
import RijksMuseum

class LocalFeedStore {
    
    typealias DataRepresentation = (feed: [FeedItem], timestamp: Date)
    
    enum LoadResult: Equatable {
        static func == (lhs: LocalFeedStore.LoadResult, rhs: LocalFeedStore.LoadResult) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty):
                return true
            case (.result(let lData), .result(let rData)):
                return lData.feed == rData.feed && lData.timestamp == rData.timestamp
            default:
                return false
            }
        }
        
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
            _ = try Data(contentsOf: storeURL)
            completion(.success(.empty))
        } catch {
            completion(.failure(error))
        }
        
        
    }
    
    func save(data: DataRepresentation,
              completion: @escaping (Result<Void, Error>) -> Void) {
        
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
