//
//  ImageLoaderTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import XCTest


class CacheStub: URLCache {
    
    var stubs: [URL: Data] = [:]
    
    func stub(data: Data, for url: URL) {
        stubs[url] = data
    }
    
    func removeStubs() {
        stubs.removeAll()
    }
    
    override func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        guard let url = request.url, let data = stubs[url] else {
            return nil
        }
        return CachedURLResponse(response: URLResponse(url: request.url!, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil),
                                 data: data)
    }
    
    override func storeCachedResponse(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
        guard let url = request.url else { return }
        stubs[url] = cachedResponse.data
    }
    
}


class ImageLoader {
    
    private let cache: URLCache
    private let session: URLSession
    
    init(session: URLSession = .shared, cache: URLCache) {
        self.session = session
        self.cache = cache
    }
    
    func load(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = session.dataTask(with: url)
        self.cache.getCachedResponse(for: task) { [unowned self] response in
            if let response = response {
                completion(.success(response.data))
                return
            }
            loadFrom(url, completion: completion)
        }
    }
    
    private func loadFrom(_ url: URL,
                          completion: @escaping (Result<Data, Error>) -> Void) {
        session.dataTask(with: url) { [unowned self] (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse,
               let data = data,
               self.isValid(httpResponse),
               let _ = UIImage(data: data) {
                self.cache.storeCachedResponse(CachedURLResponse(response: response!,
                                                                 data: data),
                                               for: URLRequest(url: url))
                completion(.success(data))
                return
            }
            completion(.failure(ImageLoaderError.invalidResponse))
        }.resume()
    }
    
    private func isValid(_ response: HTTPURLResponse) -> Bool {
        (200..<300).contains(response.statusCode)
    }
    
    enum ImageLoaderError: Error {
        case invalidResponse
    }
    
}

class ImageLoaderTests: XCTestCase {

    override func setUpWithError() throws {
        URLProtocolStub.startIntercepting()
    }
    
    override func tearDownWithError() throws {
        URLProtocolStub.stopIntercepting()
    }
    
    func test_init_doesNotRequestNetwork() {
        var requestCount = 0
        URLProtocolStub.observe { _ in
            requestCount += 1
        }
        let _ = makeSUT()
        XCTAssertEqual(requestCount, 0, "expected 0 requests, got \(requestCount) instead.")
    }
    
    func test_load_doesNotRequestNetworkOnCacheHit() {
        var requestCount = 0
        URLProtocolStub.observe { _ in
            requestCount += 1
        }
        let (sut, cache) = makeSUT()
        let data = anyUIImage().pngData()!
        let imageURL = anyURL()
        cache.stub(data: data, for: imageURL)
        expect(sut, toLoadFrom: imageURL, toLoadWith: .success(data))
        XCTAssertEqual(requestCount, 0, "expected 0 requests, got \(requestCount) instead.")
    }
    
    func test_load_requestNetworkOnCacheMiss() {
        var requestCount = 0
        let exp = XCTestExpectation(description: "waiting for network request")
        URLProtocolStub.observe { _ in
            requestCount += 1
            exp.fulfill()
        }
        let (sut, _) = makeSUT()
        sut.load(from: anyURL()) { _ in }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(requestCount, 1, "expected 1 requests, got \(requestCount) instead.")
    }
    
    func test_load_cachesApiResultWithHttp200ResponseAndValidData() {
        let (sut, cacheSpy) = makeSUT()
        let imageURL = anyURL()
        let expectedData = anyUIImage().pngData()!
        URLProtocolStub.stub(withData: expectedData,
                             response: httpResponse(withCode: 200),
                             error: nil)
        expect(sut, toLoadFrom: imageURL, toLoadWith: .success(expectedData))
        XCTAssertEqual(cacheSpy.stubs[imageURL], expectedData, "expected \(expectedData), got \(String(describing: cacheSpy.stubs[imageURL])) instead.")
    }
    
    func test_load_doesNotCacheNonHttp200ResponseAndValidData() {
        let (sut, cacheSpy) = makeSUT()
        let imageURL = anyURL()
        let invalidCodes = [0, 199, 300, 400, 500]
        for code in invalidCodes {
            URLProtocolStub.stub(withData: anyUIImage().pngData(),
                                 response: httpResponse(withCode: code),
                                 error: nil)
            expect(sut, toLoadFrom: imageURL, toLoadWith: .failure(anyNSError()))
            XCTAssertEqual(cacheSpy.stubs[imageURL], nil, "expected nil, got \(String(describing: cacheSpy.stubs[imageURL])) instead.")
        }
    }
    
    func test_load_doesNotCacheHttp200ResponseAndInvalidData() {
        let (sut, cacheSpy) = makeSUT()
        let imageURL = anyURL()
        let invalidCodes = [0, 199, 300, 400, 500]
        for code in invalidCodes {
            URLProtocolStub.stub(withData: "".data(using: .utf8),
                                 response: httpResponse(withCode: code),
                                 error: nil)
            expect(sut, toLoadFrom: imageURL, toLoadWith: .failure(anyNSError()))
            XCTAssertEqual(cacheSpy.stubs[imageURL], nil, "expected nil, got \(String(describing: cacheSpy.stubs[imageURL])) instead.")
        }
    }
    
    func test_load_failsOnEmptyApiResponse() {
        let (sut, cacheSpy) = makeSUT()
        let imageURL = anyURL()
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: nil)
        expect(sut, toLoadFrom: imageURL, toLoadWith: .failure(anyNSError()))
        XCTAssertNil(cacheSpy.stubs[imageURL], "expected no cache got \(String(describing: cacheSpy.stubs[imageURL]))")
        XCTAssertTrue(cacheSpy.stubs.keys.isEmpty, "expected empty cache")
    }
    
    func test_load_failsOnApiError() {
        let (sut, cacheSpy) = makeSUT()
        let imageURL = anyURL()
        URLProtocolStub.stub(withData: nil,
                             response: nil,
                             error: anyNSError())
        expect(sut, toLoadFrom: imageURL, toLoadWith: .failure(anyNSError()))
        XCTAssertNil(cacheSpy.stubs[imageURL], "expected no cache got \(String(describing: cacheSpy.stubs[imageURL]))")
        XCTAssertTrue(cacheSpy.stubs.keys.isEmpty, "expected empty cache")
    }
    
    // MARK: -helpers
    
    func makeSUT(file: StaticString = #file, line: UInt = #line) -> (ImageLoader, CacheStub) {
        let cache = CacheStub()
        cache.removeStubs()
        let sut = ImageLoader(cache: cache)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(cache, file: file, line: line)
        return (sut, cache)
    }
    
    func expect(_ sut: ImageLoader,
                toLoadFrom imageURL: URL,
                toLoadWith expectedResult: Result<Data, Error>,
                file: StaticString = #file,
                line: UInt = #line) {
        let exp = XCTestExpectation(description: "waiting for load completion")
        sut.load(from: imageURL) { capturedResult in
            switch (capturedResult, expectedResult) {
            case (.failure, .failure):
                ()
            case (.success(let capturedImage), .success(let expectedImage)):
                XCTAssertTrue(capturedImage == expectedImage, "expected \(expectedImage) images, got \(capturedImage).", file: file, line: line)
            default:
                XCTFail("expected \(expectedResult) got \(capturedResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    func anyUIImage() -> UIImage {
        UIImage(systemName: "trash")!
    }
    
}
