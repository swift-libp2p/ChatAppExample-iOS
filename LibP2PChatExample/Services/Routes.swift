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
    // Register the `/chat/` route
    app.group("chat") { routes in
        // Within the chat route we register an endpoint at `1.0.0`
        // This version of the chat protocol, 1.0.0, uses messages that are delimited by 'new line characters (\n)'.
        // Instead of having to scan for these 'new line characters' we can install a built in channel handler (.newLineDelimited) that does it for us.
        // The `.newLineDelimited` handler will also take of appending new lines onto outbound messages for us.
        routes.on("1.0.0", handlers: [.newLineDelimited]) { req -> Response<String> in
            // Make sure the peer is Authenticated
            // Because we've installed a security module (Noise) the remotePeer is guarenteed to be set.
            // We could force unwrap the optional here, but we use a guard statement just in case.
            guard let peer = req.remotePeer else { req.logger.warning("Error: Unidentified Request!"); return .close }

            // Handle the various stages of a request
            switch req.event {

                // `.ready` simply indicates that the connection/stream has been opened is `.ready` to start sending and receiving data.
                case .ready:
                    // Because this is an inbound stream, we just wait for the peer to send some data by returning `.stayOpen`
                    return .stayOpen

                // `.data` gets called everytime there's a message passed to us from the remote peer.
                // Because we've installed the `.newLineDelimited` handler, `.data` is called with exactly one message at a time.
                // ex: The peer sends the following data "nickname:Bob\nmessage:Hi Alice\nmessage:How are you?\n"
                //     The .data event will get called 3 times sequentially
                //     .data("nickname:Bob")
                //     .data("message:Hi Alice")
                //     .data("message:How are you?")
                // After we parse the data, we can send the message to our `MyService.delegate` in order to update the UI
                // Then we return .stayOpen because the peer might not be done sending data, and we're open to receiving more.
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

                // `.closed` gets called when the remote peer closes their end of the stream
                // We simply respond with a similar `.close` event so both parties know the stream has been closed gracefully
                case .closed:
                    // The `request` object contains a bunch of useful things such as connection stats.
                    // This is an example of how to log out the Connection Metadata once the connection has closed.
                    req.eventLoop.scheduleTask(in: .seconds(1)) {
                        req.logger.debug("\(req.connection.stats)")
                    }
                    return .close

                // The `.error` event gets called when something go wrong.
                // There's lots of stuff happening behind the scenes, sometimes things don't work out the way you intended
                // You can try and react to the error via the `error` passed in
                // We respond to any errors with a `.close` event.
                // Libp2p will determine if we can write the close event on stream, or if the stream needs to be forcefully closed.
                case .error(let error):
                    req.logger.error("Error: \(error)")
                    return .close
            }
        }

        // If later on a new version of the chat protocol gets rolled out we could add support for it here
        // Let's assume version 2.0.0 uses VarInt length prefixed messages as opposed to new line characters.
        /// ```
        /// routes.on("2.0.0", handlers: [.varIntLengthPrefixed]) { req -> Response<String> in
        ///    ...
        /// }
        /// ```
    }
}
