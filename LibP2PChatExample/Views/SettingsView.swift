//
//  SettingsView.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 6/1/22.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var viewModel:ViewModel
    
    @State var nickname = ""
    @State var peerIDDeleted:Bool = false
    @State var isAlertPresented:Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("PEER ID")) {
                if let pid = viewModel.p2pService.savedPeerID {
                    Text("\(pid.b58String)")
                } else {
                    Text("A new PeerID will be generated next time you start the app")
                }
                Button(action: {
                    peerIDDeleted = true
                    viewModel.p2pService.deletePeerID()
                }) {
                    Text("Delete")
                        .foregroundColor(peerIDDeleted ? .gray : .red)
                        .disabled(peerIDDeleted)
                }
            }
            .onAppear {
                peerIDDeleted = viewModel.p2pService.savedPeerID == nil
            }
            
            
            Section(header: Text("PROFILE")) {
                TextField("Nickname", text: $nickname)
                    .onChange(of: nickname) { _ in
                        self.viewModel.nickname = nickname
                    }
                    .onAppear {
                        if let nickname = self.viewModel.nickname {
                            self.nickname = nickname
                        }
                    }
            }
            
//                Section(header: Text("NOTIFICATIONS")) {
//                    Toggle(isOn: $notificationsEnabled) {
//                        Text("Enabled")
//                    }
//                    Picker(selection: $previewIndex, label: Text("Show Previews")) {
//                        ForEach(0 ..< previewOptions.count) {
//                            Text(self.previewOptions[$0])
//                        }
//                    }
//                }
            
            Section(header: Text("CHATS")) {
                Button("Delete All Chats") {
                    isAlertPresented = true
                }
                .foregroundColor(.red)
                .alert(isPresented: $isAlertPresented) {
                    Alert(
                        title: Text("Delete All Chats?"),
                        message: Text("This will delete all of your saved chats. This action can't be undone. Would you like to proceed?"),
                        primaryButton: .cancel(Text("Cancel")) {
                            print("Do nothing...")
                        },
                        secondaryButton: .destructive(Text("Yes, Delete All Chats!")) {
                            viewModel.deleteChats()
                        }
                    )
                }
            }
            
            Section(header: Text("ABOUT")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1.1")
                }
                Link(
                    destination: URL(string: "https://github.com/swift-libp2p")!,
                    label:  {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("The swift-libp2p GitHub Repo")
                        }
                        
                    }
                )
                Link(
                    destination: URL(string: "https://github.com/swift-libp2p/libp2p-chat-app.git")!,
                    label:  {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("The source code for this app")
                        }
                    }
                )
            }
        }
        .navigationBarTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(ViewModel())
        }
    }
}
