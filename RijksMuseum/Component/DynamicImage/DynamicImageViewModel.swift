//
//  DynamicImageViewModel.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation
import UIKit

public class DynamicImageViewModel: ObservableObject {
    
    @Published public var image: UIImage?
    
    private let imageLoader: ImageLoaderProtocol
    private let imageMapper: ImageMapper
    private let url: URL
    
    public init(loader: ImageLoaderProtocol, mapper: ImageMapper, url: URL) {
        self.imageLoader = loader
        self.imageMapper = mapper
        self.url = url
    }
    
    public func load(completion: @escaping () -> () = { }) {
        imageLoader.load(from: url) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure:
                completion()
            case .success(let imageData):
                self.map(imageData, completion: completion)
            }
        }
    }
    
    private func map(_ data: Data, completion: @escaping () -> ()) {
        self.imageMapper.map(data: data) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure:
                ()
            case .success(let image):
                self.image = image
            }
            completion()
        }
    }
    
}

extension DynamicImageViewModel {
    static var preview: DynamicImageViewModel {
        DynamicImageViewModel(loader: ImageLoader(cache: URLCache()),
                              mapper: SimpleImageMapper(),
                              url: URL(string: "https://any-url.com")!)
    }
}
