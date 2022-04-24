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

class RemoteFeedLoader {
    
    let session: URLSession
    
    init(session: URLSession) {
        self.session = session
    }
    
    func load(from url: URL) {
        session.dataTask(with: url) { _, _, _ in
        }.resume()
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
        sut.load(from: URL(string: "https://any-url.com")!)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(requestCount, 1, "not expecting requests on init. got \(requestCount).")
    }
    
    // MARK: helpers
    func makeSUT() -> RemoteFeedLoader {
        return RemoteFeedLoader(session: .shared)
    }


}
