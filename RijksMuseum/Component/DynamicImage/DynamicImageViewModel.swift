//
//  DynamicImageViewModel.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation
import UIKit

class DynamicImageViewModel: ObservableObject {
    
    @Published var image: UIImage?
    
    private let imageLoader: ImageLoader
    private let imageMapper: ImageMapper
    private let url: URL
    
    init(loader: ImageLoader, mapper: ImageMapper, url: URL) {
        self.imageLoader = loader
        self.imageMapper = mapper
        self.url = url
    }
    
    func load() {
        imageLoader.load(from: url) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure:
                ()
            case .success(let imageData):
                self.map(imageData)
            }
        }
    }
    
    private func map(_ data: Data) {
        print("DYN MAP")
        self.imageMapper.map(data: data) { [weak self] result in
            print("DYN MAP Done")
            guard let self = self else { return }
            switch result {
            case .failure:
                ()
            case .success(let image):
                self.image = image
            }
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
