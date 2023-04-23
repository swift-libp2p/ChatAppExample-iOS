//
//  Routes.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 4/21/23.
//

import LibP2P

/// Chat Route
/// We register support for the /chat/1.0.0 endpoint where peers, who also support /chat/1.0.0, can communicate with us.
func routes(_ app: Application) throws {
    app.group("chat") { routes in
        routes.on("1.0.0", handlers: [.newLineDelimited]) { req -> Response<String> in
            // Make sure the peer is Authenticated
            guard let peer = req.remotePeer else { req.logger.warning("Error: Unidentified Request!"); return .close }
            // Handle the various stages of a request
            switch req.event {
            case .ready:
                //app.console.info("\(peer): Joined the chat!")
                return .stayOpen
                
            case .data(let payload):
                if let str = String(data: Data(payload.readableBytesView), encoding: .utf8) {
                    app.console.info("\(peer): \(str)")
                    if str.hasPrefix("nickname:") {
                        req.myService.delegate?.on(nickname: str.replacingOccurrences(of: "nickname:", with: ""), from: peer)
                    } else {
                        req.myService.delegate?.on(message: str, from: peer)
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
