//
//  FeedListViewModel.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import Foundation

class FeedListViewModel: ObservableObject {
    
    @Published var isLoading: Bool = false
    @Published var feed: [FeedItem] = []
    @Published var loadFailed: Bool = false
    @Published var selectedItem: FeedItem? = nil
    
    private let loader: FeedLoader
    
    init(loader: FeedLoader) {
        self.loader = loader
    }
    
    func load() {
        self.loadFailed = false
        self.isLoading = true
        self.loader.load { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let items):
                self.feed = items
            case .failure:
                self.loadFailed = true
            }
        }
    }
    
}

extension FeedListViewModel {
    static var preview: FeedListViewModel {
        FeedListViewModel(loader: FeedLoaderStub())
    }
}
