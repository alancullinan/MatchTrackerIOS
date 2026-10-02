//
//  MatchTrackerApp.swift
//  MatchTracker
//
//  Created by Alan Cullinan on 01/10/2026.
//

import SwiftData
import SwiftUI

@main
struct MatchTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try Store.container()
        } catch {
            // Never fall back to a fresh, empty store: that would look like every match had gone.
            fatalError("Could not open the match store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MatchListView()
        }
        .modelContainer(container)
    }
}
