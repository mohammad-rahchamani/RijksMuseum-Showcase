//
//  MainThreadDecorator.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation
import UIKit

class MainThreadDecorator<T> {
    let decoratee: T
    
    init(_ decoratee: T) {
        self.decoratee = decoratee
    }
    
    func runOnMainThread(_ action: @escaping () -> ()) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.runOnMainThread(action)
            }
            return
        }
        action()
    }
}

extension MainThreadDecorator: FeedLoader where T == FeedLoader {
    
    func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        decoratee.load { [weak self] result in
            guard let self = self else { return }
            self.runOnMainThread {
                completion(result)
            }
        }
    }
    
}

extension MainThreadDecorator: ImageMapper where T == ImageMapper {
    
    func map(data: Data, completion: @escaping (Result<UIImage, Error>) -> Void) {
        decoratee.map(data: data) { [weak self] result in
            guard let self = self else { return }
            self.runOnMainThread {
                completion(result)
            }
        }
    }
    
}
