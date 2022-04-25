//
//  CacheStub.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation

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
