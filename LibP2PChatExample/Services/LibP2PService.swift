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

/// Any class that conforms to the ChatDelegate can register themselves on the LibP2PService to get notified of Chat events
protocol ChatDelegate {
    func on(message:String, from:PeerID)
    func on(nickname:String, from:PeerID)
}

/// We extend the Request struct with a computed var that provides access to a shared instance of our LibP2PService.
/// This allows us to interact with the LibP2PService without our Route handlers.
extension Request {
    var myService: LibP2PService { LibP2PService.shared }
}

/// We create a simple LibP2PService Singleton that is responsible for...
/// - starting and stoping libp2p
/// - configuring our libp2p networking stack
/// - registering our Route handlers
/// - listening for peer discovery events
/// - sending messages to connected peers
class LibP2PService {
    static let shared = LibP2PService()

    private var app:Application
    
    internal var delegate:ChatDelegate? = nil
    
    //private var lna:LocalNetworkAuthorization
    
    private var pingTask:RepeatedTask? = nil
    
    public var savedPeerID:PeerID? {
        if let pid = UserDefaults.standard.data(forKey: "MyPeerID") {
            return try? PeerID(marshaledPrivateKey: pid)
        } else if let pem = UserDefaults.standard.string(forKey: "MyPeerID") {
            return try? PeerID(pem: pem, password: "Test123")
        } else {
            return nil
        }
    }
    
    private init() {
        let peerID:PeerID
        if let existingPeerID = UserDefaults.standard.data(forKey: "MyPeerID") {
            peerID = try! PeerID(marshaledPrivateKey: existingPeerID)
        } else if let existingPeerID = UserDefaults.standard.string(forKey: "MyPeerID") {
            peerID = try! PeerID(pem: existingPeerID, password: "Test123")
        } else {
            peerID = try! PeerID(.Ed25519)
            if let pem = try? peerID.exportKeyPair(as: .privatePEMString(encryptedWithPassword: "Test123")) {
                UserDefaults.standard.set(String(pem), forKey: "MyPeerID")
            }
        }
                 
        // Configure our libp2p stack
        self.app = Application(.testing, peerID: peerID)
        // Set the applications log level
        self.app.logger.logLevel = .notice
        // We set the Connections idleTimeout to a large value like 30 seconds
        self.app.connectionManager.setIdleTimeout(.seconds(30))
        self.app.security.use(.noise)
        self.app.muxers.use(.mplex)
        self.app.discovery.use(.mdns)
        self.app.servers.use(.tcp(host: "0.0.0.0", port: 10000))
        
        // Register the `/chat/1.0.0` Protocol / Route
        try! routes(self.app)
        
        // Used to request Local Network Access
        //self.lna = LocalNetworkAuthorization()
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
        //guard await self.lna.requestAuthorization() else { return }
        if app.isRunning { return }
        try app.start()
        self.app.logger.notice("LibP2P Started!")
        
        // This gets called for all discovered peers (they may or may not supoprt /chat/1.0.0)
        // Same as `app.events.on(app, event: .discovered(...))`
        app.discovery.onPeerDiscovered(app) { peer in
            self.app.logger.notice("We discovered a peer: \(peer)")
            self.app.connections.getConnectionsToPeer(peer: peer.peer, on: nil).whenSuccess { conns in
                if conns.isEmpty {
                    try? self.app.newStream(to: peer.addresses.first!, forProtocol: "/chat/1.0.0")
                }
            }
        }
        
        // We remove any old addresses upon disconnection...
        // TODO: Libp2p should mark a Multiaddress in our Peerbook as old/unconnectable upon a dial failing.
        app.events.on(self, event: .disconnected({ conn, peerID in
            if let peerID = peerID { let _ = self.app.peers.removeAllAddresses(forPeer: peerID) }
        }))
        
        // Sechedule our repeating Ping Users Task
        self.pingTask = app.eventLoopGroup.any().scheduleRepeatedTask(initialDelay: .seconds(15), delay: .seconds(15), { task in
            self.pingDiscoveredUsers()
        })
    }
    
    public func stop() {
        guard app.isRunning else { return }
        self.pingTask?.cancel()
        app.shutdown()
    }
    
    public func send(message:String, to peer:PeerID) {
        guard self.app.isRunning else { print("LibP2P needs to be running in order to send messages!"); return }
        // There's a lot happening in this `newRequest` call, let's break it down
        // We have some data (our `message`) that we would like to send to our `peer`
        // Libp2p offers a `Request` type that makes sending a single chunk of data easier than opening up and managing a streaming channel (similar to an HTTP Request)
        // So we create a `newRequest` to our `peer`, destined for the `/chat/1.0.0` protocol, with the `message` we'd like to send them
        //
        // The next couple params are a little more in depth...
        //  `style` provides the Request with a hint at what kind of behavior to expect.
        //      `.noResponseExpected` means the stream will imediately request to be closed after sending the data, not waiting for a response / reply. (like a PUT request)
        //      `.responseExpected` means that we expect data back from the peer (like a GET request)
        //     Because our `/chat/1.0.0` doesn't support read reciepts we set this to `.noResponseExpected`
        //     If, let's say, `/chat/2.0.0` supported delivery confirmations (read receipts), we could change this to `.responseExpected` and parse the returned message for confirmation of delivery.
        //  `withHandlers` let's us configure the `/chat/1.0.0` stream with custom Channel Handlers (similar to middleware if you're familiar with other server side frameworks).
        //     When we registered our `/chat/1.0.0` route earlier (in our initiailizer) we told Libp2p that the `/chat/1.0.0` should be `.newLineDelimited` (Routes.swift).
        //     Therefor, when set to `.inherit`, libp2p can automagically use this info to configure the `/chat/1.0.0` stream with the same channel handlers.
        //     If, for some reason, you wanted to have a unique channel handler configuration for this particular requets, you can add any ChannelHandlers you'd like to here.
        //       ex: perhaps adding additional Logging handlers if you were trying to debug a request
        self.app.newRequest(to: peer, forProtocol: "/chat/1.0.0", withRequest: Data(message.utf8), style: .noResponseExpected, withHandlers: .inherit).whenComplete { result in
            switch result {
            case .failure(let error):
                self.app.logger.error("Error: \(error)")
            case .success:
                self.app.logger.trace("Sent message to peer: \(peer)")
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
                    return continuation.resume(returning: connectedness == .Connected)
                }
            }
        }
    }
    
    /// This recurring task acts as a Keep-Alive service for Peers that support the `/chat/1.0.0` protocol
    /// We Ping these peers at an interval that's shorter than our Idle Timeout set above (30 seconds) in order to keep the Connection alive
    public func pingDiscoveredUsers() {
        let _ = self.app.peers.getPeers(supportingProtocol: .init("chat/1.0.0")! ).map { peers in
            return peers.compactMap { peerID in
                self.app.connections.connectedness(peer: try! PeerID(cid: peerID), on: nil).map { connectedness -> (String, EventLoopFuture<TimeAmount>)? in
                    switch connectedness {
                    case .Connected:
                        return (peerID, self.app.identify.ping(peer: try! PeerID(cid: peerID)).always { result in
                            self.app.logger.debug("Ping Result: \(result)")
                        })
                    default:
                        return nil
                    }
                }
            }.flatten(on: self.app.eventLoopGroup.any())
        }
    }
}
