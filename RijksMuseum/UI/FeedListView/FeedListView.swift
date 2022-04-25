//
//  FeedListView.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import SwiftUI

public struct FeedListView: View {
    
    let loadingIdentifier = "loading"
    let errorIdentifier = "error"
    let emptyViewIdentifier = "empty-list"
    let listIdentifier = "feed-list"
    
    @ObservedObject var viewModel: FeedListViewModel
    let imageLoader: ImageLoader
    let imageMapper: ImageMapper
    
    var loadingView: some View {
        Text("Loading...")
            .accessibilityIdentifier(loadingIdentifier)
    }
    
    var errorView: some View {
        Text("Feed Loading Failed.")
            .accessibilityIdentifier(errorIdentifier)
    }
    
    var emptyListView: some View {
        Text("There is nothing to show.")
            .accessibilityIdentifier(emptyViewIdentifier)
    }
    
    var dataView: some View {
        List(viewModel.feed) { feedItem in
            feedItemView(for: feedItem)
        }
        .accessibilityIdentifier(listIdentifier)
    }
    
    @ViewBuilder
    func feedItemView(for item: FeedItem) -> some View {
        NavigationLink(tag: item,
                       selection: $viewModel.selectedItem,
                       destination: {
            LazyView(ItemDetailsView(item: viewModel.selectedItem!))
        }) {
            HStack(alignment: .center) {
                DynamicImageView(loader: imageLoader,
                                 mapper: imageMapper,
                                 url: URL(string: item.webImage.url)!,
                                 placeHolder: {
                    Text("loading")
                })
                    .frame(width: 40, height: 40)
                Text(item.title)
            }
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                if viewModel.loadFailed {
                    errorView
                } else if viewModel.isLoading {
                    loadingView
                } else {
                    dataView
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
    }
}

struct FeedListView_Previews: PreviewProvider {
    static var previews: some View {
        FeedListView(viewModel: .preview,
                     imageLoader: ImageLoader(cache: URLCache()),
                     imageMapper: SimpleImageMapper())
    }
}
