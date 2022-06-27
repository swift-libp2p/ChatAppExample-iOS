//
//  LibP2PChatExampleApp.swift
//  LibP2PChatExample
//
//  Created by Brandon Toms on 5/28/22.
//

import SwiftUI

@main
struct LibP2PChatExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ViewModel())
        }
    }
}
