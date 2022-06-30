# LibP2P Chat App Example (iOS)

[![](https://img.shields.io/badge/made%20by-Breth-blue.svg?style=flat-square)](https://breth.app)
[![](https://img.shields.io/badge/project-libp2p-yellow.svg?style=flat-square)](http://libp2p.io/)

> An Example iOS App that showcases how libp2p can be used to chat with peers on the same network (LAN). 

## Table of Contents

- [Overview](#overview)
- [Why?](#why)
- [Try it out](#try-it-out)
- [Contributing](#contributing)
- [Credits](#credits)
- [License](#license)

## Overview

The app uses mDNS to automatically discover other libp2p peers on the same Local Area Network (LAN). Once discovered, you can begin a message thread with them similar to the Messages app.

## Why?

It's an example of how you can integrate swift-libp2p into an iOS App! 🥳

## Try it out

Check it out by...

1) Cloning this repo

2) Create an new iOS Project
   1) XCode -> File -> New -> Project
   2) Select iOS -> App
   3) Give it a Product Name of 'LibP2PChatExample'
   4) Make sure you select
      - Interface -> SwiftUI
      - Language -> Swift
      - Uncheck -> Use Core Data
      - Uncheck -> Include Tests

3) Drag and drop the directories and files from this repo into your new project. 

4) Include the swift package dependencies by clicking on your project at the top of the navigator.
   - Include the following packages:
      - https://github.com/swift-libp2p/swift-libp2p
      - https://github.com/swift-libp2p/swift-libp2p-noise
      - https://github.com/swift-libp2p/swift-libp2p-mplex
      - https://github.com/swift-libp2p/swift-libp2p-mdns

5) Select an iOS Simulator to run the app on. 

6) Build and Run the Project!

7) Run the app on two devices connected to the same LAN and they should discover one another within a few seconds and a chat dialog will become available!

## Contributing

Contributions are welcomed! This code is very much a proof of concept. I can guarantee you there's a better / safer way to accomplish the same results. Any suggestions, improvements, or even just critques, are welcome! 

Let's make this code better together! 🤝

## Credits

- [SwiftUI Chat Interface Inspiration](https://youtu.be/Pk1c1EjGtQ0)
- [swift-nio](https://github.com/apple/swift-nio)
- [swift-vapor](https://github.com/vapor/vapor) 
- [LibP2P Spec](https://github.com/libp2p/specs)

## License

[MIT](LICENSE) © 2022 Breth Inc.
