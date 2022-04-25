//
//  LazyView.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import SwiftUI

struct LazyView<Content: View>: View {
    
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}
