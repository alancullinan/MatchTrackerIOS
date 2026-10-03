import SwiftUI

/// The app's tabs: Matches (the home screen), Panels and Settings. Each tab has
/// its own navigation stack; the match screen hides the tab bar.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Matches", systemImage: "sportscourt") {
                MatchListView()
            }
            Tab("Panels", systemImage: "person.3") {
                NavigationStack { PanelListView() }
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#if DEBUG
#Preview("Tabs", traits: .sampleMatches) {
    RootView()
}
#endif
