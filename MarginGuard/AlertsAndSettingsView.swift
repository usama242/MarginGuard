import SwiftUI

// MARK: - Smart Notifications, What-If Top-Up Calculator & Theme Settings
public struct AlertsAndSettingsView: View {
    @ObservedObject var store: PortfolioStore
    @State private var desiredSurvivalPrice: Double = 3600.0

    public init(store: PortfolioStore) {
        self.store = store
    }

    public var body: some View {
        let snap = store.analytics

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROTECTION & PREFERENCES")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                        .tracking(1.1)
                    Text("Smart Alerts & Cash Top-Up")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)
                }

                // 1. What-If Crash Survival & Cash Deposit Calculator
                whatIfSurvivalCalculator(snap: snap)

                // 2. Smart Notification Scenarios Card
                smartNotificationsCard(snap: snap)

                // 3. Appearance (Light / Dark / System) & App Icon Concept Preview
                appearanceAndIconCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
    }

    // MARK: - 1. What-If Cash Deposit Calculator
    private func whatIfSurvivalCalculator(snap: PortfolioAnalytics) -> some View {
        let targetMaintMargin = snap.leverageWeightedUnits * desiredSurvivalPrice * 0.50
        let projectedEquityAtTarget = snap.accountValueNow
            + snap.netSignedUnits * (desiredSurvivalPrice - snap.livePrice)
            - snap.projectedAdditionalFees
        let requiredDeposit = max(0, targetMaintMargin - projectedEquityAtTarget)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "lifepreserver.fill")
                    .foregroundStyle(GlassPalette.accentGold)
                Text("WHAT-IF CRASH SURVIVAL CALCULATOR")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)
            }

            Text("Calculate how much extra cash to deposit today so your positions survive a crash to your target price over \(snap.projectedDays) days.")
                .font(.system(size: 12))
                .foregroundStyle(GlassPalette.textSecondary)

            HStack {
                Text("Target Crash Survival Price")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GlassPalette.textPrimary)
                Spacer()
                Text("$\(String(format: "%.0f", desiredSurvivalPrice))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(GlassPalette.accentGold)
            }

            Slider(
                value: $desiredSurvivalPrice,
                in: max(50, snap.livePrice * 0.55)...snap.livePrice,
                step: 25
            )
            .tint(GlassPalette.accentGold)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXTRA CASH DEPOSIT NEEDED TODAY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textSecondary)
                    Text(requiredDeposit <= 0 ? "$0 (Already Safe)" : "+$\(String(format: "%.2f", requiredDeposit))")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(requiredDeposit <= 0 ? GlassPalette.safeEmerald : GlassPalette.dangerCoral)
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.12)))
        }
        .liquidGlassCard(cornerRadius: 24, padding: 18)
    }

    // MARK: - 2. Smart Notification Scenarios
    private func smartNotificationsCard(snap: PortfolioAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(GlassPalette.accentGold)
                Text("SMART NOTIFICATION SCENARIOS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)
                Spacer()
                Button("Test Alert") {
                    NotificationManager.shared.sendSampleTestNotification(analytics: snap)
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(GlassPalette.accentGold.opacity(0.2)))
                .foregroundStyle(GlassPalette.accentGold)
            }

            Toggle("Revolut 80% / 60% Margin Call Alert", isOn: $store.alertPrefs.enableMarginCallAlerts)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GlassPalette.textPrimary)
                .tint(GlassPalette.accentGold)

            Toggle("50% Stop-Out Buffer Alert ($\(Int(store.alertPrefs.liquidationBufferDollars)) buffer)", isOn: $store.alertPrefs.enableLiquidationProximity)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GlassPalette.textPrimary)
                .tint(GlassPalette.accentGold)

            if store.alertPrefs.enableLiquidationProximity {
                Slider(value: $store.alertPrefs.liquidationBufferDollars, in: 25...500, step: 25)
                    .tint(GlassPalette.accentGold)
            }

            Toggle("Custom Price Floor Alert ($\(Int(store.alertPrefs.targetPriceFloor)))", isOn: $store.alertPrefs.enableCustomPriceAlert)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GlassPalette.textPrimary)
                .tint(GlassPalette.accentGold)

            if store.alertPrefs.enableCustomPriceAlert {
                Slider(value: $store.alertPrefs.targetPriceFloor, in: 2500...5000, step: 25)
                    .tint(GlassPalette.accentGold)
            }

            Toggle("Weekend 3x Overnight Fee Roll Reminder", isOn: $store.alertPrefs.enableWeekendSwapReminder)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GlassPalette.textPrimary)
                .tint(GlassPalette.accentGold)
        }
        .liquidGlassCard(cornerRadius: 24, padding: 18)
    }

    // MARK: - 3. Light & Dark Semantic Theme Switcher + App Icon Preview
    private var appearanceAndIconCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("APPEARANCE & LIQUID GLASS THEME")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(GlassPalette.accentGold)

            Picker("Theme Mode", selection: $store.themeMode) {
                ForEach(AppThemeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 14) {
                // Miniature Liquid Glass App Icon Concept Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.08, green: 0.11, blue: 0.22), Color(red: 0.03, green: 0.05, blue: 0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(GlassPalette.accentGold.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(18))
                        .offset(x: -5, y: -4)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundStyle(GlassPalette.safeEmerald)
                        )
                        .offset(x: 5, y: 4)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Liquid Gold Prism Icon")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)
                    Text("Adaptive Light & Dark semantic colors with translucent material refraction.")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
            }
        }
        .liquidGlassCard(cornerRadius: 24, padding: 18)
    }
}
