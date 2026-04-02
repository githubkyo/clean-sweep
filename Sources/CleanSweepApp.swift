import SwiftUI

@main
struct CleanSweepApp: App {
    @State private var scanner = StorageScanner()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(scanner)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 640)
    }
}
