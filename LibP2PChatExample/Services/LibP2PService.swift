//
//  LibP2PService.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 5/29/22.
//

import LibP2P
import LibP2PNoise
import LibP2PMPLEX
import LibP2PMDNS

protocol ChatDelegate {
    func on(message:String, from:PeerID)
    func on(nickname:String, from:PeerID)
}

struct MyService {
    let service: LibP2PService

    func on(message:String, from:PeerID) {
        service.delegate?.on(message: message, from: from)
    }
    
    func on(nickname:String, from:PeerID) {
        service.delegate?.on(nickname: nickname, from: from)
    }
}

extension Request {
    var myService: MyService {
        .init(service: LibP2PService.shared)
    }
}

class LibP2PService {
    static let shared = LibP2PService()

    private let app:Application
    
    internal var delegate:ChatDelegate? = nil
    
    private var lna:LocalNetworkAuthorization
    
    public var savedPeerID:PeerID? {
        if let pid = UserDefaults.standard.data(forKey: "MyPeerID") {
            return try? PeerID(marshaledPrivateKey: pid)
        } else {
            return nil
        }
    }
    
    private init() {
        let peerID:PeerID
        if let existingPeerID = UserDefaults.standard.data(forKey: "MyPeerID") {
            peerID = try! PeerID(marshaledPrivateKey: existingPeerID)
        } else {
            peerID = try! PeerID(.Ed25519)
            if let id = try? peerID.marshalPrivateKey() {
                UserDefaults.standard.set(Data(id), forKey: "MyPeerID")
            }
        }
                                
        self.app = Application(.production, peerID: peerID)
        self.app.security.use(.noise)
        self.app.muxers.use(.mplex)
        self.app.discovery.use(.mdns)
        self.app.servers.use(.tcp(host: "0.0.0.0", port: 10000)) //4
        self.app.logger.logLevel = .info
        
        // Register the Chat Route
        try! routes(app)
        
        self.lna = LocalNetworkAuthorization()
    }
    
    public func deletePeerID() {
        UserDefaults.standard.removeObject(forKey: "MyPeerID")
    }
    
    public func register(register:AnyObject, event: EventBus.EventHandler) {
        self.app.events.on(register, event: event)
    }
    
    public func topology(_ reg:TopologyRegistration) {
        self.app.topology.register(reg)
    }
    
    public func start() async throws {
        guard await self.lna.requestAuthorization() else { return }
        if app.isRunning { return }
        try app.start()
        self.app.logger.logLevel = .notice
        
        /// This gets called for all discovered peers (they may or may not supoprt /chat/1.0.0)
        /// Same as `app.events.on(app, event: .discovered(...))`
        app.discovery.onPeerDiscovered(app) { peer in
            self.app.logger.notice("We discovered a peer: \(peer)")
            self.app.connections.getConnectionsToPeer(peer: peer.peer, on: nil).whenSuccess { conns in
                if conns.isEmpty {
                    try? self.app.newStream(to: peer.addresses.first!, forProtocol: "/chat/1.0.0")
                }
            }
        }
    }
    
    public func stop() {
        guard app.isRunning else { return }
        app.shutdown()
    }
    
    public func send(message:String, to peer:PeerID) {
        //print("TODO: Should send `\(message)` to \(peer))")
        guard self.app.isRunning else { print("LibP2P needs to be running in order to send messages!"); return }
        self.app.newRequest(to: peer, forProtocol: "/chat/1.0.0", withRequest: Data(message.utf8), style: .noResponseExpected, withHandlers: .inherit).whenComplete { result in
            switch result {
            case .failure(let error):
                self.app.logger.error("Error: \(error)")
            case .success:
                self.app.logger.trace("Sent message to peers: \(peer)")
            }
        }
    }
    
    public func isConnectedTo(peer:PeerID) async -> Bool {
        await withCheckedContinuation { continuation in
            self.app.connections.connectedness(peer: peer, on: nil).whenComplete { result in
                switch result {
                case .failure(_):
                    return continuation.resume(returning: false)
                case .success(let connectedness):
                    return continuation.resume(returning: .Connected == connectedness)
                }
            }
        }
    }
}

/// Chat Route
func routes(_ app: Application) throws {
    app.group("chat") { routes in
        routes.on("1.0.0", handlers: [.newLineDelimited]) { req -> ResponseType<String> in
            
            guard let peer = req.remotePeer else { req.logger.warning("Error: Unidentified Request!"); return .close }
            switch req.event {
            case .ready:
                //app.console.info("\(peer): Joined the chat!")
                return .stayOpen
                
            case .data(let payload):
                if let str = String(data: Data(payload.readableBytesView), encoding: .utf8) {
                    app.console.info("\(peer): \(str)")
                    if str.hasPrefix("nickname:") {
                        req.myService.on(nickname: str.replacingOccurrences(of: "nickname:", with: ""), from: peer)
                    } else {
                        req.myService.on(message: str, from: peer)
                    }
                }
                return .stayOpen
                
            case .closed:
                //app.console.info("\(peer): Left the chat!")
                req.eventLoop.scheduleTask(in: .seconds(1)) {
                    req.logger.debug("\(req.connection.stats)")
                }
                return .close
                
            case .error(let error):
                req.logger.error("Error: \(error)")
                return .close
            }
        }
    }
}
