//
//  ChatModel.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 5/29/22.
//

import Foundation
import PeerID

class Chat: ObservableObject, Identifiable, Codable {
    var id:String { peer.id }
    @Published var peer:Person
    @Published var messages:[Message]
    
    var lastMessage:Message? {
        self.messages.last
    }
    
    internal init(peer: Person, messages: [Message]) {
        self.peer = peer
        self.messages = messages
    }
    
    enum CodingKeys: String, CodingKey {
        case peer
        case messages
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(peer, forKey: .peer)
        try container.encode(messages, forKey: .messages)
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        peer = try values.decode(Person.self, forKey: .peer)
        messages = try values.decode([Message].self, forKey: .messages)
    }
}

class Person:ObservableObject, Identifiable, Codable {
    var id:String
    var peer:PeerID
    @Published var nickname:String
    @Published var isActive:Bool
    
    var initials:String {
        let parts = nickname.split(separator: " ")
        if parts.count > 1, let f = parts.first, let l = parts.last {
            return "\(f.first!)\(l.first!)"
        } else {
            return String(nickname.first!)
        }
    }
    
    internal init(id: String, peer: PeerID, nickname: String, isActive: Bool) {
        self.id = id
        self.peer = peer
        self.nickname = nickname
        self.isActive = isActive
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case peer
        case nickname
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(peer.marshalPublicKey(), forKey: .peer)
        try container.encode(nickname, forKey: .nickname)
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        let pubKey = try values.decode([UInt8].self, forKey: .peer)
        peer = try PeerID(marshaledPublicKey: Data(pubKey))
        nickname = try values.decode(String.self, forKey: .nickname)
        isActive = false
    }
}

struct Message:Equatable, Identifiable, Codable {
    
    enum MessageType: Codable {
        case sent
        case received
    }
    
    let id:UUID
    let date:Date
    let contents:String
    let type:MessageType
    
    public init(_ contents:String, type:MessageType, date:Date = Date(), id:UUID? = nil) {
        self.id = id ?? UUID()
        self.date = date
        self.contents = contents
        self.type = type
    }
}

extension Chat {
    static var Example = Chat(
        peer: Person(
            id: "12D3KooWDNTc3SYQ8Va26MfPWH3MBM3AUcJKXjQqWfsPQrHh1QeW",
            peer: try! PeerID(.Ed25519),
            nickname: "Alice W",
            isActive: false
        ),
        messages: [
            Message("Hey! How's it going?", type: .received),
            Message("Pretty good! How've you been??", type: .sent),
            Message("That's awesome! Have you seen any movies lately?", type: .received),
            Message("Yeah! I just saw Encanto! Such a fun film!", type: .sent),
            Message("OOOO, I should definitely check it out", type: .received),
            Message("I also want to the see the new Top Gun! 🛩😎", type: .received),
            Message("Heck Yes! Let's go!", type: .sent),
            Message("You free Friday?", type: .sent),
            Message("Sure am! See ya there!", type: .received),
            Message("Gotta go though! Goodbye 👋", type: .received)
        ]
    )
}
