//
//  RemoteFeedLoaderTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import XCTest

class URLProtocolStub: URLProtocol {
    
    struct Stub {
        var data: Data?
        var response: URLResponse?
        var error: Error?
    }
    
    static var observer: ((URLRequest) -> ())?
    static var stub: Stub?
    
    static func observe(_ closure: @escaping (URLRequest) -> ()) {
        observer = closure
    }
    
    static func stub(withData data: Data?, response: URLResponse?, error: Error?) {
        stub = Stub(data: data, response: response, error: error)
    }
    
    static func startIntercepting() {
        URLProtocol.registerClass(self)
    }
    
    static func stopIntercepting() {
        URLProtocol.unregisterClass(self)
        stub = nil
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        URLProtocolStub.observer?(request)
        guard let stub = URLProtocolStub.stub else { return }
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        
    }
    
}

struct FeedImage: Equatable, Codable {
    let guid: String
    let url: String
    
    init(guid: String, url: String) {
        self.guid = guid
        self.url = url
    }
}


struct FeedItem: Equatable, Codable {
    
    let id: String
    let objectNumber: String
    let title: String
    let longTitle: String
    let webImage: FeedImage
    let headerImage: FeedImage
    
    init(id: String,
         objectNumber: String,
         title: String,
         longTitle: String,
         webImage: FeedImage,
         headerImage: FeedImage) {
        self.id = id
        self.objectNumber = objectNumber
        self.title = title
        self.longTitle = title
        self.webImage = webImage
        self.headerImage = headerImage
    }
}


class RemoteFeedLoader {
    
    let session: URLSession
    
    init(session: URLSession) {
        self.session = session
    }
    
    func load(from url: URL,
              completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse, self.isValid(httpResponse) {
                completion(self.parse(data))
            } else {
                completion(.failure(RemoteFeedLoaderError.invalidResponse))
            }
        }.resume()
    }
    
    private func isValid(_ response: HTTPURLResponse) -> Bool {
        (200..<300).contains(response.statusCode)
    }
    
    private func parse(_ data: Data?) -> Result<[FeedItem], Swift.Error> {
        guard data != nil else {
            return .failure(RemoteFeedLoaderError.invalidResponse)
        }
        return .success([])
    }
    
    private enum RemoteFeedLoaderError: Error {
        case invalidResponse
        case decodeError
    }
    
}

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
        sut.load(from: anyURL()) { _ in }
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
        URLProtocolStub.stub(withData: Data(),
                             response: httpResponse(withCode: 200),
                             error: anyNSError())
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNonHttpResponse() throws {
        URLProtocolStub.stub(withData: nil,
                             response: URLResponse(url: anyURL(),
                                                   mimeType: nil,
                                                   expectedContentLength: 0,
                                                   textEncodingName: nil),
                             error: nil)
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    func test_load_failsOnNonHttpResponseAndData() throws {
        URLProtocolStub.stub(withData: Data(),
                             response: URLResponse(url: anyURL(),
                                                   mimeType: nil,
                                                   expectedContentLength: 0,
                                                   textEncodingName: nil),
                             error: nil)
        let sut = makeSUT()
        expect(sut, toCompleteWithResult: .failure(anyNSError()))
    }
    
    // MARK: helpers
    func makeSUT() -> RemoteFeedLoader {
        return RemoteFeedLoader(session: .shared)
    }
    
    func expect(_ sut: RemoteFeedLoader,
                toLoadFrom url: URL = URL(string: "https://any-url.com")!,
                toCompleteWithResult expectedResult: Result<[FeedItem], Error>,
                file: StaticString = #file,
                line: UInt = #line) {
        let exp = XCTestExpectation(description: "waiting for load result")
        sut.load(from: url) { capturedResult in
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
    
    func httpResponse(withCode code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(),
                        statusCode: code,
                        httpVersion: nil,
                        headerFields: nil)!
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

}
