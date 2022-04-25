//
//  DynamicImageViewModelTests.swift
//  RijksMuseumTests
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import XCTest
import RijksMuseum


class ImageLoaderSpy: ImageLoaderProtocol {
    
    var messages: [URL: (Result<Data, Error>) -> Void] = [:]
    
    func load(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        messages[url] = completion
    }
    
    func completeLoad(for url: URL, withResult result: Result<Data, Error>) {
        messages[url]!(result)
    }
    
}

class DynamicImageViewModelTests: XCTestCase {

    func test() {
        let (_ , spy) = makeSUT(url: anyURL())
        XCTAssertTrue(spy.messages.isEmpty, "expected no messages upon creation")
    }
    
    func test_load_failsOnLoaderError() {
        let url = anyURL()
        let (sut, spy) = makeSUT(url: url)
        sut.load()
        spy.completeLoad(for: url, withResult: .failure(anyNSError()))
        XCTAssertNil(sut.image, "expected nil on load error.")
    }
    
    func test_load_FailsOnInvalidData() {
        let url = anyURL()
        let (sut, spy) = makeSUT(url: url)
        sut.load()
        spy.completeLoad(for: url, withResult: .success(Data()))
        XCTAssertNil(sut.image, "expected nil on invalid data.")
    }
    
    // unable to compare UIImages!
    
//    func test_load_SucceedsOnValidData() {
//        let url = anyURL()
//        let (sut, spy) = makeSUT(url: url)
//        let exp = XCTestExpectation(description: "waiting for load completion")
//        sut.load() {
//            exp.fulfill()
//        }
//        let expectedImage = anyUIImage()
//        spy.completeLoad(for: url, withResult: .success(expectedImage.jpegData(compressionQuality: 1)!))
//        wait(for: [exp], timeout: 1)
//        XCTAssertEqual(sut.image, expectedImage, "expected same")
//    }
    
    // MARK: -helpers
    
    func makeSUT(url: URL,
                 file: StaticString = #file,
                 line: UInt = #line) -> (DynamicImageViewModel, ImageLoaderSpy) {
        let spy = ImageLoaderSpy()
        let sut = DynamicImageViewModel(loader: spy, mapper: SimpleImageMapper(), url: url)
        trackForMemoryLeaks(spy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return(sut, spy)
    }
    
}
