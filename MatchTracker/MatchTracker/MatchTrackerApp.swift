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
            #if DEBUG
            // `-sampleStore`: an in-memory store with the sample matches, so the
            // app can be tried in the Simulator without touching saved matches.
            if CommandLine.arguments.contains("-sampleStore") {
                container = try Store.container(inMemory: true)
                try SampleMatches.insert(into: container.mainContext)
                return
            }
            #endif
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
