import SwiftUI

struct ContentView: View {
    @StateObject private var vm = HAViewModel()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }

            EntityBrowserView()
                .tabItem { Label("Entities", systemImage: "list.bullet") }

            GlassesPreviewView()
                .tabItem { Label("Glasses", systemImage: "eyeglasses") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(vm)
        .environmentObject(SettingsStore.shared)
        .onAppear { vm.connect() }
    }
}

#Preview {
    ContentView()
}
