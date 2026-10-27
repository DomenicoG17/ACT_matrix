import SwiftUI

@main
struct ACTMatrixApp: App {
    @StateObject private var store = MatrixStore()

    var body: some Scene {
        WindowGroup {
            MatrixView()
                .environmentObject(store)
                .preferredColorScheme(nil)
        }
    }
}
