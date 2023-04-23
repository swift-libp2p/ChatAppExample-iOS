//
//  ViewModel.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 5/31/22.
//

import LibP2P
import SwiftUI

class ViewModel:ObservableObject, ChatDelegate {
    @Published var groups:[String]
    @Published var chats:[Chat]
    
    @Published var nickname:String? = nil {
        didSet {
            /// Save the nickname in user defaults
            UserDefaults.standard.set(nickname, forKey: "Nickname")
        }
    }
    
    public var p2pService:LibP2PService
    
//    public var activeChats:[Chat] {
//        self.chats.filter { $0.peer.isActive }
//    }
//    
//    public var inactiveChats:[Chat] {
//        self.chats.filter { !$0.peer.isActive }
//    }
    
    init() {
        // Grab a shared instance of our LibP2PService
        self.p2pService = LibP2PService.shared
        
        // Dummy data
        self.groups = ["No Groups Yet"]
        self.chats = []
        
        self.p2pService.topology(
            TopologyRegistration(
                protocol: "/chat/1.0.0",
                handler: TopologyHandler(
                    onConnect: onNewChatBuddy,
                    onDisconnect: onChatBuddyLeft
                )
            )
        )
        
        /// Register ourselves as the ChatDelegate
        self.p2pService.delegate = self
        
        /// Restore the chats if possible...
        print("Attempting to restore chats")
        self.restoreChats()
        
        if let nickname = UserDefaults.standard.string(forKey: "Nickname") {
            self.nickname = nickname
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            print("Attempting to save chats")
            self.saveChats()
            self.p2pService.stop()
        }
    }
    
    private func onNewChatBuddy(peer:PeerID, conn:Connection) {
        DispatchQueue.main.async {
            guard !self.chats.contains(where: { $0.peer.peer == peer }) else {
                // Mark the existing peer as active
                if let index = self.chats.firstIndex(where: { $0.peer.peer == peer }) {
                    self.chats[index].peer.isActive = true
                }
                /// Let the existing peer know of our nickname if we have one set...
                DispatchQueue.global().async {
                    if let nickname = self.nickname {
                        self.send(nickname: nickname, to: peer)
                    }
                }
                return
            }
            
            print("New Chat Buddy")
            self.chats.append(
                Chat(
                    peer: Person(
                        id: peer.b58String,
                        peer: peer,
                        nickname: peer.shortDescription,
                        isActive: true
                    ),
                    messages: []
                )
            )
            /// Let the new peer know of our nickname if we have one set...
            DispatchQueue.global().async {
                if let nickname = self.nickname {
                    self.send(nickname: nickname, to: peer)
                }
            }
        }
        
    }
    
    private func onChatBuddyLeft(peer:PeerID) {
        Task {
            DispatchQueue.main.async {
                print("Chat Buddy Left")
                if let index = self.chats.firstIndex(where: { $0.peer.peer == peer }) {
                    self.chats[index].peer.isActive = false
                }
            }
        }
    }
    
    internal func on(message:String, from:PeerID) {
        DispatchQueue.main.async {
            print("We got a message from libP2P!")
            if let index = self.chats.firstIndex(where: { $0.peer.peer == from }) {
                self.chats[index].messages.append(
                    Message(message, type: .received)
                )
            } else {
                print("Got message from unknown peer... \(from) -> \(message)")
            }
        }
    }
    
    internal func on(nickname:String, from:PeerID) {
        DispatchQueue.main.async {
            print("We got a nickname from libP2P!")
            if let index = self.chats.firstIndex(where: { $0.peer.peer == from }) {
                self.chats[index].peer.nickname = nickname
            }
        }
    }
    
    public func startP2PService() async {
        try? await self.p2pService.start()
    }
    
    public func stopP2PService() {
        /// Stop the service
        self.p2pService.stop()
        /// Mark all peers inactive
        for i in 0..<self.chats.count {
            self.chats[i].peer.isActive = false
        }
        /// Save Chats
        self.saveChats()
    }
    
    public func send(message:String, to chat:Chat) -> Message? {
        if let index = self.chats.firstIndex(where: { $0.id == chat.id }) {
            let msg = Message(message, type: .sent)
            self.chats[index].messages.append(msg)
            self.p2pService.send(message: message, to: chat.peer.peer)
            return msg
        }
        return nil
    }
    
    private func send(nickname:String, to peer:PeerID) {
        self.p2pService.send(message: "nickname:\(nickname)", to: peer)
    }
    
    public func isActive(peer:Person) -> Bool {
        if let index = self.chats.firstIndex(where: { $0.peer.peer == peer.peer }) {
            return self.chats[index].peer.isActive
        } else {
            return false
        }
    }
    
    /// Save the chats out to a file
    private func saveChats() {
        if let chatData = try? JSONEncoder().encode(self.chats) {
            UserDefaults.standard.set(chatData, forKey: "MyChats")
            print("Saved chats")
        } else {
            print("Failed to save chats")
        }
        
//        let fileManager = FileManager.default
//        do {
//            let documentDirectory = try fileManager.url(for: ., in: .userDomainMask, appropriateFor:nil, create:false)
//            let fileURL = documentDirectory.appendingPathComponent("chats.json")
//
//            let chatsData = try JSONEncoder().encode(self.chats)
//            if !fileManager.fileExists(atPath: fileURL.path) {
//                print("Creating a chats.json file")
//                fileManager.createFile(atPath: fileURL.path, contents: chatsData)
//            } else {
//                print("overwriting chats.json file")
//                try chatsData.write(to: fileURL)
//            }
//
//        } catch {
//            print(error)
//        }
    }
    
    /// Restore the chats if a file exists
    private func restoreChats() {
        if let chatData = UserDefaults.standard.data(forKey: "MyChats") {
            if let chats = try? JSONDecoder().decode([Chat].self, from: chatData) {
                self.chats = chats
                print("Restored chats!")
            }
        } else {
            print("Failed to restore chats")
        }
        
//        let fileManager = FileManager.default
//        do {
//            let documentDirectory = try fileManager.url(for: .applicationDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
//            let fileURL = documentDirectory.appendingPathComponent("chats.json")
//            if let chatsData = fileManager.contents(atPath: fileURL.path) {
//                print("Got contents from our chats.json")
//                self.chats = try JSONDecoder().decode([Chat].self, from: chatsData)
//                print(self.chats)
//            } else {
//                print("No data at chats.json")
//            }
//        } catch {
//            print(error)
//        }
    }
    
    public func deleteChats() {
        // Delete all chats...
        self.chats = []
        // Save the new empty chat list...
        self.saveChats()
    }
}
