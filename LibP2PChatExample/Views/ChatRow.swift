//
//  ChatRow.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 5/29/22.
//

import SwiftUI

struct ChatRow: View {
    
    @EnvironmentObject var viewModel:ViewModel
    
    @ObservedObject var chat:Chat
    
    var body: some View {
        HStack(spacing: 8) {
            PeerIconView(
                peer: chat.peer,
                frame: CGSize(width: 70, height: 70)
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(chat.peer.nickname)
                        .font(.body)
                        .bold()
                    Spacer()
                    Text(chat.messages.last?.date.formatted(date: .numeric, time: .shortened) ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.trailing)
                HStack {
                    Text(chat.lastMessage?.contents ?? "...")
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(height: 50, alignment: .top)
                        .padding(.trailing)
                        .font(.body)
                }
            }
        }
    }
}

struct ChatRow_Previews: PreviewProvider {
    static var previews: some View {
        ChatRow(chat: Chat.Example)
            .environmentObject(ViewModel())
    }
}
