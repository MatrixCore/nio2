//
//  NioApp.swift
//  Nio
//
//  Created by Finn Behrens on 08.06.22.
//

import SwiftUI
import NioKit

@main
struct NioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(NioAccountManager.preview)
        }
    }
}
