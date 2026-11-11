import SwiftUI

@main
struct MarginGuardApp: App {
    @StateObject private var store = PortfolioStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootContainerView(store: store)
                .preferredColorScheme(store.themeMode.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await store.refreshMarketPricesNow() }
                    }
                }
        }
    }
}

struct RootContainerView: View {
    @ObservedObject var store: PortfolioStore
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            if !store.hasCompletedOnboarding {
                OnboardingWizardView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView(store: store)
                        .tabItem {
                            Label("Guard", systemImage: "shield.lefthalf.filled")
                        }
                        .tag(0)

                    ChartsAnalyticsView(store: store)
                        .tabItem {
                            Label("Charts", systemImage: "chart.xyaxis.line")
                        }
                        .tag(1)

                    AlertsAndSettingsView(store: store)
                        .tabItem {
                            Label("Protection", systemImage: "bell.badge.waveform.fill")
                        }
                        .tag(2)
                }
                .tint(GlassPalette.accentGold)
            }
        }
    }
}
