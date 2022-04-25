//
//  ContentView.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/24/22.
//

import SwiftUI

struct ContentView: View {
    
    let feedListViewModel: FeedListViewModel
    let imageLoader: ImageLoader
    let imageMapper: ImageMapper
    
    init() {
        let storeURL = FileManager.default
            .urls(for: .cachesDirectory,
                     in: .userDomainMask)
            .first!.appendingPathComponent("localFeed.store")
        let feedStore = LocalFeedStore(storeURL: storeURL)
        let serverURL = URL(string: "https://www.rijksmuseum.nl/api/en/collection?key=9b2htUjo&involvedMaker=Rembrandt+van+Rijn")!
        let remoteLoader = RemoteFeedLoader(session: .shared,
                                            url: serverURL)
        let cacheAge: TimeInterval = 5*60
        let cachedLoader = FeedCache(store: feedStore,
                                     loader: remoteLoader,
                                     maxAge: cacheAge,
                                     currentDate: Date.init)
        feedListViewModel = FeedListViewModel(loader: MainThreadDecorator(cachedLoader))
        let imageCache = URLCache(memoryCapacity: 50 * 1024 * 1024,
                                  diskCapacity: 250 * 1024 * 1024,
                                  directory: nil)
        self.imageLoader = ImageLoader(session: .shared,
                                       cache: imageCache)
        let imageMapper = SimpleImageMapper()
        let mainThreadImageMapper: ImageMapper = MainThreadDecorator(imageMapper)
        self.imageMapper = mainThreadImageMapper
    }
    
    var body: some View {
        FeedListView(viewModel: feedListViewModel,
                     imageLoader: imageLoader,
                     imageMapper: imageMapper)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
