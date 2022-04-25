//
//  ItemDetailsView.swift
//  RijksMuseum
//
//  Created by Mohammad Rahchamani on 4/25/22.
//

import SwiftUI

struct ItemDetailsView: View {
    
    let item: FeedItem
    
    init(item: FeedItem) {
        self.item = item
    }
    
    var body: some View {
        VStack {
            Spacer()
            Text(item.title)
            Spacer()
            Text(item.longTitle)
            Spacer()
        }
        .padding()
    }
}

struct ItemDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ItemDetailsView(item: FeedItem(id: "", objectNumber: "", title: "", longTitle: "", webImage: FeedImage(guid: "", url: ""), headerImage: FeedImage(guid: "", url: "")))
    }
}
