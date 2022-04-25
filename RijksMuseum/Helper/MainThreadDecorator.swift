//
//  MainThreadDecorator.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation

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
