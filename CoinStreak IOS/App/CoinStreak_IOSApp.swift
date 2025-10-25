//
//  CoinStreak_IOSApp.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI
import CoreText

@main
struct CoinStreak_IOSApp: App {
    
    #if DEBUG
    private static var didStageThisLaunch = false
    #endif
    
    init() {
        
        /*#if DEBUG
        if !Self.didStageThisLaunch {
            Self.didStageThisLaunch = true
            // Pick a scenario to simulate (0=Starter, 1=Lab, 2=next, etc.)
            ProgressionManager.debugStagePreUpdateState(pretendTileVisited: 2)
        }
        #endif*/
        
        Haptics.shared.prepare()
        registerAllBundleFonts()
        _ = InstallIdentity.getOrCreateInstallId()
        // No auto-retire on fresh install anymore.
        if InstallMarker.isFreshInstall() {
            InstallMarker.markInstalled()
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private func registerAllBundleFonts() {
    // Works whether fonts are in a group (“grey folder”) or a real subdirectory.
    for ext in ["ttf", "otf", "ttc"] {
        if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
            for url in urls {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
                // (Optional) print errors for debugging:
                // if let e = error?.takeRetainedValue() { print("Font reg failed:", e) }
            }
        }
    }
}


