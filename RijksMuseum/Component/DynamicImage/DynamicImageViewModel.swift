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
    
    init(loader: ImageLoader, mapper: ImageMapper) {
        self.imageLoader = loader
        self.imageMapper = mapper
    }
    
    func load(from url: URL) {
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
        self.imageMapper.map(data: data) { [weak self] result in
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
                              mapper: SimpleImageMapper())
    }
}
