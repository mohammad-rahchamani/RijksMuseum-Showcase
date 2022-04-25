//
//  DynamicImageView.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import SwiftUI

struct DynamicImageView<PlaceHolder: View>: View {
    
    @StateObject var viewModel: DynamicImageViewModel
    private let placerHolder: () -> PlaceHolder
    
    init(loader: ImageLoader,
         mapper: ImageMapper,
         url: URL,
         @ViewBuilder placeHolder: @escaping () -> PlaceHolder) {
        self._viewModel = StateObject(wrappedValue: DynamicImageViewModel(loader: loader,
                                                                          mapper: mapper,
                                                                          url: url))

        self.placerHolder = placeHolder
    }
    
    @ViewBuilder
    func imageView() -> some View {
        if let image = self.viewModel.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            self.placerHolder()
        }
    }
    
    var body: some View {
        imageView()
            .onAppear {
                self.viewModel.load()
            }
    }
}

struct DynamicImageView_Previews: PreviewProvider {
    static var previews: some View {
        
        DynamicImageView(loader: ImageLoader.init(cache: URLCache()),
                         mapper: SimpleImageMapper(),
                         url: URL(string: "https://lh3.googleusercontent.com/gShVRyvLLbwVB8jeIPghCXgr96wxTHaM4zqfmxIWRsUpMhMn38PwuUU13o1mXQzLMt5HFqX761u8Tgo4L_JG1XLATvw=s0")!,
                         placeHolder: {
            Image(systemName: "trash")
                .resizable()
        })
    }
}
