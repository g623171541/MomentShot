//
//  MomentShotApp.swift
//  MomentShot
//

import SwiftUI

@main
struct MomentShotApp: App {
    init() {
        MediaStore.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
