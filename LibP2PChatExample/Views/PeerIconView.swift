//
//  PeerIconView.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 5/31/22.
//

import SwiftUI

struct PeerIconView: View {
    
    @EnvironmentObject var viewModel:ViewModel
    
    @ObservedObject var peer:Person
    let frame:CGSize
    
    var body: some View {
        ZStack {
            let isActive = viewModel.isActive(peer: peer)
            Circle()
                .strokeBorder(isActive ? .green : .gray, lineWidth: 3)
                .background(Circle().fill(.clear))
                .frame(width: frame.width, height: frame.height)
                
            Text(peer.initials)
                .padding(frame.width / 10)
                .font(.system(size: 500))
                .minimumScaleFactor(0.01)
                .frame(width: frame.width - 8, height: frame.height - 8)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .background(.gray)
                .clipShape(Circle())
        }
        .frame(width: frame.width, height: frame.height)
    }
}

struct PeerIconView_Previews: PreviewProvider {
    static var previews: some View {
        PeerIconView(
            peer: Chat.Example.peer,
            frame: CGSize(width: 300, height: 300)
        )
        .environmentObject(ViewModel())
    }
}
