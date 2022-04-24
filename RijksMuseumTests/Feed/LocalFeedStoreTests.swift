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
    private let queue = DispatchQueue(label: "\(type(of: LocalFeedStore.self))",
                                      qos: .background,
                                      attributes: .concurrent)
    
    init(storeURL: URL) {
        self.storeURL = storeURL
        self.setupStore()
    }
    
    private func setupStore() {
        guard !FileManager.default.fileExists(atPath: storeURL.path) else { return }
        try? "".data(using: .utf8)?.write(to: storeURL)
    }
    
    func load(completion: @escaping (Result<LoadResult, Error>) -> Void) {
        let storeURL = storeURL
        queue.async {
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
    }
    
    func save(data: DataRepresentation,
              completion: @escaping (Result<Void, Error>) -> Void) {
        let storeURL = storeURL
        queue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let encodedData = try encoder.encode(data)
                try encodedData.write(to: storeURL)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func delete(completion: @escaping (Result<Void, Error>) -> Void) {
        let storeURL = storeURL
        queue.async(flags: .barrier) {
            do {
                try Data().write(to: storeURL)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
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
        let expectedResult = anyDataRepresentation()
        save(expectedResult, to: sut)
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
    }
    
    func test_load_hasNoSideEffectsOnStoreWithData() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let expectedResult = anyDataRepresentation()
        save(expectedResult, to: sut)
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
        expect(sut, toCompleteLoadWith: .success(.result(expectedResult)))
    }
    
    func test_save_completesSuccessfullyOnValidDataAndValidStoreURL() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let expectedResult = anyDataRepresentation()
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
        let data = anyDataRepresentation()
        expect(sut, toSave: data, andCompleteSaveWith: .failure(anyNSError()))
    }
    
    func test_delete_failsOnStoreError() {
        let sut = makeSUT(storeURL: invalidStoreURL())
        expect(sut, toCompleteDeleteWith: .failure(anyNSError()))
    }
    
    func test_delete_finishesSuccessfullyOnEmptyStore() {
        let sut = makeSUT(storeURL: storeURLForTest())
        expect(sut, toCompleteDeleteWith: .success(()))
    }
    
    func test_delete_removesDataFromStoreWithData() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let data = LocalFeedStore.DataRepresentation(feed: [anyFeedItem()], timestamp: Date())
        save(data, to: sut)
        delete(sut)
        expect(sut, toCompleteLoadWith: .success(.empty))
    }
    
    func test_sideEffects_runSeriallyToAvoidRaceConditions() {
        let sut = makeSUT(storeURL: storeURLForTest())
        let op1 = XCTestExpectation(description: "waiting for operation 1")
        let op2 = XCTestExpectation(description: "waiting for operation 2")
        let op3 = XCTestExpectation(description: "waiting for operation 3")
        let op4 = XCTestExpectation(description: "waiting for operation 4")
        let op5 = XCTestExpectation(description: "waiting for operation 5")
        var completedOperations: [XCTestExpectation] = []
        sut.save(data: anyDataRepresentation()) { _ in
            completedOperations.append(op1)
            op1.fulfill()
        }
        sut.delete { _ in
            completedOperations.append(op2)
            op2.fulfill()
        }
        sut.save(data: anyDataRepresentation()) { _ in
            completedOperations.append(op3)
            op3.fulfill()
        }
        sut.delete { _ in
            completedOperations.append(op4)
            op4.fulfill()
        }
        sut.save(data: anyDataRepresentation()) { _ in
            completedOperations.append(op5)
            op5.fulfill()
        }
        wait(for: [op1, op2, op3, op4, op5], timeout: 1)
        XCTAssertEqual(completedOperations, [op1, op2, op3, op4, op5], "expected op1, op2, op3, op4, op5 in order, got \(completedOperations) instead.")
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
    
    func expect(_ sut: LocalFeedStore,
                toCompleteDeleteWith expectedResult: Result<Void, Error>,
                file: StaticString = #file,
                line: UInt = #line) {
        let exp = XCTestExpectation(description: "waiting for delete completion")
        sut.delete { capturedResult in
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
        let exp = XCTestExpectation(description: "waiting for save completion")
        store.save(data: data) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    func delete(_ store: LocalFeedStore) {
        let exp = XCTestExpectation(description: "waiting for deolete completion")
        store.delete { _ in
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
    
    func anyDataRepresentation() -> LocalFeedStore.DataRepresentation {
        LocalFeedStore.DataRepresentation(feed: [anyFeedItem(), anyFeedItem()], timestamp: Date())
    }
    
    func invalidStoreURL() -> URL {
        anyURL()
    }
    
    func removeStoreFile() {
        try? FileManager.default.removeItem(at: storeURLForTest())
    }

}
