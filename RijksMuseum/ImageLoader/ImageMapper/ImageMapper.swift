//
//  ImageMapper.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation
import UIKit

public protocol ImageMapper {
    func map(data: Data, completion: @escaping (Result<UIImage, Error>) -> Void)
}
