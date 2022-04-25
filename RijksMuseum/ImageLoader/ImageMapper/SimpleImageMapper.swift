//
//  SimpleImageMapper.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation
import UIKit

class SimpleImageMapper: ImageMapper {
    
    func map(data: Data,
             completion: @escaping (Result<UIImage, Error>) -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let _ = self else { return }
            guard let image = UIImage(data: data) else {
                completion(.failure(ImageMapperError.invalidData))
                return
            }
            completion(.success(image))
        }
    }
    
    enum ImageMapperError: Error {
        case invalidData
    }
    
}
