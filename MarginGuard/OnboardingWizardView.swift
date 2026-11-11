import SwiftUI

// MARK: - Step-by-Step Setup & Full Precision Position/Balance Editor
public struct OnboardingWizardView: View {
    @ObservedObject var store: PortfolioStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = 1

    // Step 2 Draft Position State
    @State private var draftSide: TradeSide = .buy
    @State private var draftEntryPrice: String = "4488.20"
    @State private var draftUnits: String = "0.50"

    // Step 3 Balance Sync State
    @State private var balanceText: String = "3435.40"
    @State private var showAdvancedParams: Bool = false
    @State private var customLeverage: Double = 20.0
    @State private var customAnnualFeePercent: Double = 7.5

    public init(store: PortfolioStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 18) {
                wizardHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 1:
                            step1SelectInstrument
                        case 2:
                            step2AddAndEditPositions
                        case 3:
                            step3AccountBalanceSync
                        default:
                            step4SmartProtectionSetup
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }

                wizardBottomBar
            }
        }
        .onAppear {
            balanceText = String(format: "%.2f", store.analytics.accountValueNow)
            customLeverage = store.selectedPreset.defaultLeverage
            customAnnualFeePercent = store.selectedPreset.defaultAnnualFeeRate * 100.0
        }
    }

    private var wizardHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEP \(currentStep) OF 4")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                        .tracking(1.2)
                    Text(stepTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)
                }
                Spacer()
                if store.hasCompletedOnboarding {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(GlassPalette.textSecondary)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { step in
                    Button {
                        withAnimation(.spring(response: 0.3)) { currentStep = step }
                    } label: {
                        Capsule()
                            .fill(step <= currentStep ? GlassPalette.accentGold : GlassPalette.textSecondary.opacity(0.25))
                            .frame(height: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var stepTitle: String {
        switch currentStep {
        case 1: return "Select Your Commodity"
        case 2: return "Your Open Positions"
        case 3: return "Sync Revolut Balance"
        default: return "Price Guard & Live Alerts"
        }
    }

    // MARK: - STEP 1: Select Instrument & Live Price
    private var step1SelectInstrument: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your primary commodity or CFD. Live market price is fetched automatically every 5 seconds.")
                .font(.system(size: 14))
                .foregroundStyle(GlassPalette.textSecondary)

            VStack(spacing: 10) {
                ForEach(InstrumentPreset.presets) { preset in
                    let isSelected = store.focusTicker == preset.ticker
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            store.focusTicker = preset.ticker
                            customLeverage = preset.defaultLeverage
                            customAnnualFeePercent = preset.defaultAnnualFeeRate * 100.0
                            Task { await store.refreshMarketPricesNow() }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: preset.symbolIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isSelected ? GlassPalette.accentGold : GlassPalette.textSecondary)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(GlassPalette.accentGold.opacity(isSelected ? 0.18 : 0.06)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(GlassPalette.textPrimary)
                                Text("\(preset.ticker) • \(Int(preset.defaultLeverage))x Leverage")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(GlassPalette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isSelected ? GlassPalette.accentGold : GlassPalette.textSecondary.opacity(0.4))
                        }
                        .liquidGlassCard(
                            cornerRadius: 18,
                            padding: 13,
                            tint: isSelected ? GlassPalette.accentGold.opacity(0.10) : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - STEP 2: Add or Edit Open Positions (Full 2-Decimal Precision)
    private var step2AddAndEditPositions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter your open \(store.focusTicker) positions with exact entry prices (both '.' and ',' decimals work).")
                .font(.system(size: 14))
                .foregroundStyle(GlassPalette.textSecondary)

            if !store.positions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("OPEN POSITIONS (\(store.positions.count))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.textSecondary)
                        Spacer()
                        Button("Reset to My 3 Gold Trades") {
                            withAnimation {
                                store.positions = [
                                    CFDPosition(ticker: "XAU/USD", side: .buy, units: 0.5, entryPrice: 4488.20, leverage: 20),
                                    CFDPosition(ticker: "XAU/USD", side: .buy, units: 0.5, entryPrice: 4554.98, leverage: 20),
                                    CFDPosition(ticker: "XAU/USD", side: .buy, units: 0.5, entryPrice: 4620.00, leverage: 20)
                                ]
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GlassPalette.accentGold)
                    }

                    ForEach(Array(store.positions.enumerated()), id: \.element.id) { index, pos in
                        let pnl = pos.grossPnL(at: store.liveMarketPrice)
                        HStack {
                            Text("#\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(GlassPalette.textSecondary)
                                .frame(width: 24)

                            Text(pos.side.rawValue)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(
                                        pos.side == .buy
                                            ? GlassPalette.safeEmerald.opacity(0.2)
                                            : GlassPalette.dangerCoral.opacity(0.2)
                                    )
                                )
                                .foregroundStyle(pos.side == .buy ? GlassPalette.safeEmerald : GlassPalette.dangerCoral)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.2f", pos.units)) \(store.selectedPreset.unitLabel) @ $\(String(format: "%.2f", pos.entryPrice))")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(GlassPalette.textPrimary)
                                Text("Margin: $\(String(format: "%.2f", pos.liveMarginReserved(at: store.liveMarketPrice))) • P&L: \(String(format: "%+.2f$", pnl))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(pnl >= 0 ? GlassPalette.safeEmerald : GlassPalette.dangerCoral)
                            }
                            Spacer()
                            Button {
                                withAnimation {
                                    store.positions.removeAll { $0.id == pos.id }
                                }
                            } label: {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(GlassPalette.textSecondary.opacity(0.6))
                            }
                        }
                        .liquidGlassCard(cornerRadius: 16, padding: 12)
                    }
                }
            }

            // Add New Position Card
            VStack(alignment: .leading, spacing: 14) {
                Text("ADD ANOTHER OPEN POSITION")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)

                Picker("Side", selection: $draftSide) {
                    ForEach(TradeSide.allCases) { side in
                        Text(side.rawValue).tag(side)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    glassInputField(title: "Entry Price ($)", text: $draftEntryPrice, placeholder: "4554.98")
                    glassInputField(title: "Units (\(store.selectedPreset.unitLabel))", text: $draftUnits, placeholder: "0.50")
                }

                Button {
                    addDraftPosition()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Position #\(store.positions.count + 1)")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(GlassPalette.accentGold.opacity(0.22))
                    )
                    .foregroundStyle(GlassPalette.accentGold)
                }
            }
            .liquidGlassCard(cornerRadius: 20, padding: 16)
        }
    }

    private func addDraftPosition() {
        guard let entry = NumberParser.parse(draftEntryPrice), entry > 0,
              let units = NumberParser.parse(draftUnits), units > 0 else { return }
        let newPos = CFDPosition(
            ticker: store.focusTicker,
            side: draftSide,
            units: units,
            entryPrice: entry,
            leverage: customLeverage,
            annualOvernightRate: customAnnualFeePercent / 100.0,
            daysHeld: 0,
            isActive: true
        )
        withAnimation(.spring(response: 0.35)) {
            store.positions.append(newPos)
        }
    }

    // MARK: - STEP 3: Revolut Account Balance Sync
    private var step3AccountBalanceSync: some View {
        let snap = store.analytics
        return VStack(alignment: .leading, spacing: 16) {
            Text("Enter your Revolut Account Value or Available to Invest. We anchor it to the current market price ($\(String(format: "%.2f", store.liveMarketPrice))) so all numbers match Revolut 100%.")
                .font(.system(size: 14))
                .foregroundStyle(GlassPalette.textSecondary)

            Picker("Balance Sync Mode", selection: $store.balanceMode) {
                ForEach(BalanceInputMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 12) {
                Text(store.balanceMode.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GlassPalette.textSecondary)

                HStack {
                    Text("$")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                    TextField("3435.40", text: $balanceText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)
                        .onChange(of: balanceText) { _, newValue in
                            if let val = NumberParser.parse(newValue), val >= 0 {
                                store.syncRevolutBalance(mode: store.balanceMode, amount: val)
                            }
                        }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.12)))

                Divider().opacity(0.3)

                // Reconciled Live Preview matching Revolut
                HStack(spacing: 10) {
                    miniMetricPill(title: "Account Value", value: "$\(String(format: "%.2f", snap.accountValueNow))")
                    miniMetricPill(title: "Unrealized P&L", value: "\(String(format: "%+.2f$", snap.unrealisedPnL))")
                    miniMetricPill(title: "Margin Reserved", value: "$\(String(format: "%.2f", snap.marginReservedNow))")
                }
                HStack(spacing: 10) {
                    miniMetricPill(title: "Available to Invest", value: "$\(String(format: "%.2f", snap.availableToInvestNow))")
                    miniMetricPill(title: "Maint. Margin (50%)", value: "$\(String(format: "%.2f", snap.maintenanceMargin50))")
                    miniMetricPill(title: "1st Liq Gold Price", value: "$\(String(format: "%.2f", snap.firstLiquidationPriceNow))")
                }
            }
            .liquidGlassCard(cornerRadius: 22, padding: 18)
        }
    }

    // MARK: - STEP 4: Smart Protection Setup
    private var step4SmartProtectionSetup: some View {
        let snap = store.analytics
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 24))
                        .foregroundStyle(GlassPalette.safeEmerald)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GOLD LIQUIDATION GUARD READY")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.safeEmerald)
                        Text("1st Position Liquidates at $\(String(format: "%.2f", snap.firstLiquidationPriceNow))/oz")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.textPrimary)
                    }
                    Spacer()
                }

                Text("\(store.focusTicker) can drop by -$\(String(format: "%.2f", snap.priceDropToFirstStopOut))/oz (\(String(format: "%.1f%%", snap.priceDropPercentToFirstStopOut))) from $\(String(format: "%.2f", snap.livePrice)) before Revolut closes your highest-loss position.")
                    .font(.system(size: 13))
                    .foregroundStyle(GlassPalette.textSecondary)
            }
            .liquidGlassCard(cornerRadius: 20, padding: 16, tint: GlassPalette.safeEmerald.opacity(0.08))

            VStack(spacing: 14) {
                Toggle("80% / 60% Margin Call Alerts", isOn: $store.alertPrefs.enableMarginCallAlerts)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GlassPalette.textPrimary)
                    .tint(GlassPalette.accentGold)

                Divider().opacity(0.25)

                Toggle("Gold Liquidation Proximity Guard", isOn: $store.alertPrefs.enableLiquidationProximity)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GlassPalette.textPrimary)
                    .tint(GlassPalette.accentGold)

                Divider().opacity(0.25)

                Toggle("Weekend 3x Swap Fee Reminder", isOn: $store.alertPrefs.enableWeekendSwapReminder)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GlassPalette.textPrimary)
                    .tint(GlassPalette.accentGold)
            }
            .liquidGlassCard(cornerRadius: 20, padding: 16)
        }
    }

    private var wizardBottomBar: some View {
        HStack(spacing: 14) {
            if currentStep > 1 {
                Button {
                    withAnimation(.spring(response: 0.35)) { currentStep -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassPalette.textPrimary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                }
            }

            Button {
                if currentStep < 4 {
                    withAnimation(.spring(response: 0.35)) { currentStep += 1 }
                } else {
                    NotificationManager.shared.requestPermission()
                    store.hasCompletedOnboarding = true
                    store.startLiveActivity()
                    dismiss()
                }
            } label: {
                HStack {
                    Text(currentStep < 4 ? "Continue" : "Save & Open Guard")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: currentStep < 4 ? "arrow.right" : "checkmark.shield.fill")
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(GlassPalette.accentGold))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func glassInputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GlassPalette.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(GlassPalette.textPrimary)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.14)))
        }
    }

    private func miniMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(GlassPalette.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(GlassPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
