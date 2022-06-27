//
//  ContentView.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 5/28/22.
//

import SwiftUI
import LibP2P

struct ContentView: View {
    @EnvironmentObject var viewModel:ViewModel
    @State var isServiceRunning:Bool = false
    @State var chatSelected:Chat? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Peers") {
                        if viewModel.chats.isEmpty {
                            Text("No Peers")
                        } else {
                            ForEach(viewModel.chats.filter({$0.peer.isActive})) { chat in
                                NavigationLink(destination: {
                                    ChatView(chat: chat)
                                        .environmentObject(viewModel)
                                }) {
                                    ChatRow(chat: chat)
                                }
                            }
                            ForEach(viewModel.chats.filter({!$0.peer.isActive})) { chat in
                                NavigationLink(destination: {
                                    ChatView(chat: chat)
                                        .environmentObject(viewModel)
                                }) {
                                    ChatRow(chat: chat)
                                }
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
                .listStyle(.plain)
                Toggle("P2P Service", isOn: $isServiceRunning)
                    .padding()
                    .onChange(of: isServiceRunning) { newValue in
                        if newValue {
                            print("Attempting to start service")
                            Task { await viewModel.startP2PService() }
                        } else {
                            print("Attempting to stop service")
                            viewModel.stopP2PService()
                        }
                    }
            }
            .navigationTitle("Chats")
            .toolbar {
                NavigationLink(destination: {
                    SettingsView()
                }) {
                    Image(systemName: "gear")
                }
            }
            
        }
    }
    
    func delete(at offsets: IndexSet) {
        /// TODO: Ensure the peer isn't active. If so disconnect
        viewModel.chats.remove(atOffsets: offsets)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ViewModel())
    }
}



