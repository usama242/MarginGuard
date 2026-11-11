import SwiftUI

// MARK: - Edit / Add Open Position Sheet
public struct PositionEditorSheet: View {
    @ObservedObject var store: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    let existingPosition: CFDPosition?

    @State private var ticker: String = "XAU/USD"
    @State private var side: TradeSide = .buy
    @State private var unitsText: String = "0.50"
    @State private var entryPriceText: String = "4500.00"
    @State private var leverageText: String = "20"
    @State private var annualRateText: String = "7.5"
    @State private var purchaseDate: Date = Calendar.current.startOfDay(for: Date())

    public init(store: PortfolioStore, existingPosition: CFDPosition? = nil) {
        self.store = store
        self.existingPosition = existingPosition
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INSTRUMENT & DIRECTION")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(GlassPalette.accentGold)

                            Picker("Instrument", selection: $ticker) {
                                ForEach(InstrumentPreset.presets) { preset in
                                    Text(preset.ticker).tag(preset.ticker)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(GlassPalette.textPrimary)

                            Picker("Side", selection: $side) {
                                ForEach(TradeSide.allCases) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .liquidGlassCard(cornerRadius: 20, padding: 16)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("POSITION PARAMETERS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(GlassPalette.accentGold)

                            HStack(spacing: 12) {
                                inputField(title: "Units (\(InstrumentPreset.preset(for: ticker).unitLabel))", text: $unitsText, placeholder: "0.50")
                                inputField(title: "Entry Price ($)", text: $entryPriceText, placeholder: "4488.20")
                            }

                            HStack(spacing: 12) {
                                inputField(title: "Leverage (x)", text: $leverageText, placeholder: "20")
                                inputField(title: "Annual Swap (%)", text: $annualRateText, placeholder: "7.5")
                            }

                            DatePicker("Purchase Date", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(GlassPalette.accentGold)

                            Text("Held for \(daysSincePurchase) days. Past daily overnight fees are already reflected in your Revolut Account Value.")
                                .font(.system(size: 11))
                                .foregroundStyle(GlassPalette.textSecondary)
                        }
                        .liquidGlassCard(cornerRadius: 20, padding: 16)

                        Button {
                            savePosition()
                        } label: {
                            Text(existingPosition == nil ? "Add Position" : "Save Changes")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GlassPalette.accentGold))
                        }

                        if let existing = existingPosition {
                            Button(role: .destructive) {
                                store.positions.removeAll { $0.id == existing.id }
                                dismiss()
                            } label: {
                                Text("Delete Position")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(GlassPalette.dangerCoral)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(GlassPalette.dangerCoral.opacity(0.15)))
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(existingPosition == nil ? "Add Open Position" : "Edit Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let pos = existingPosition {
                    ticker = pos.ticker
                    side = pos.side
                    unitsText = String(format: "%.4g", pos.units)
                    entryPriceText = String(format: "%.2f", pos.entryPrice)
                    leverageText = String(format: "%.0f", pos.leverage)
                    annualRateText = String(format: "%.2f", pos.annualOvernightRate * 100.0)
                    purchaseDate = pos.purchaseDate ?? Calendar.current.date(byAdding: .day, value: -pos.daysHeld, to: Date()) ?? Date()
                } else {
                    ticker = store.focusTicker
                    let preset = store.selectedPreset
                    leverageText = String(format: "%.0f", preset.defaultLeverage)
                    annualRateText = String(format: "%.2f", preset.defaultAnnualFeeRate * 100.0)
                    entryPriceText = String(format: "%.2f", store.liveMarketPrice)
                }
            }
        }
    }

    private func savePosition() {
        let cleanUnits = Double(unitsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanEntry = Double(entryPriceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cleanLev = max(1.0, Double(leverageText.replacingOccurrences(of: ",", with: ".")) ?? 20.0)
        let cleanRate = max(0.0, Double(annualRateText.replacingOccurrences(of: ",", with: ".")) ?? 7.5) / 100.0
        let cleanDays = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: purchaseDate), to: Calendar.current.startOfDay(for: Date())).day ?? 0)

        guard cleanUnits > 0, cleanEntry > 0 else { return }

        if let existing = existingPosition,
           let idx = store.positions.firstIndex(where: { $0.id == existing.id }) {
            store.positions[idx].ticker = ticker
            store.positions[idx].side = side
            store.positions[idx].units = cleanUnits
            store.positions[idx].entryPrice = cleanEntry
            store.positions[idx].leverage = cleanLev
            store.positions[idx].annualOvernightRate = cleanRate
            store.positions[idx].daysHeld = cleanDays
            store.positions[idx].purchaseDate = purchaseDate
        } else {
            store.positions.append(CFDPosition(
                ticker: ticker,
                side: side,
                units: cleanUnits,
                entryPrice: cleanEntry,
                leverage: cleanLev,
                annualOvernightRate: cleanRate,
                daysHeld: cleanDays,
                purchaseDate: purchaseDate,
                isActive: true
            ))
        }
        dismiss()
    }

    private var daysSincePurchase: Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: purchaseDate), to: Calendar.current.startOfDay(for: Date())).day ?? 0)
    }

    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GlassPalette.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(GlassPalette.textPrimary)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.14)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sync Revolut Balance Sheet
public struct SyncBalanceSheet: View {
    @ObservedObject var store: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: BalanceInputMode = .accountValue
    @State private var amountText: String = ""
    @State private var refPriceText: String = ""

    public init(store: PortfolioStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("REVOLUT BALANCE SYNC")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.accentGold)

                        Picker("Mode", selection: $selectedMode) {
                            ForEach(BalanceInputMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(selectedMode.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(GlassPalette.textSecondary)

                        HStack {
                            Text("$")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(GlassPalette.accentGold)
                            TextField("3435.40", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(GlassPalette.textPrimary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.14)))

                        if selectedMode != .cashBaseline {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Revolut \(store.focusTicker) Price at Sync ($)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(GlassPalette.textSecondary)
                                TextField("4083.93", text: $refPriceText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(GlassPalette.textPrimary)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.14)))
                                Text("Anchors your cash baseline so every 5s price update dynamically recalculates your Account Value.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(GlassPalette.textSecondary)
                            }
                        }
                    }
                    .liquidGlassCard(cornerRadius: 22, padding: 18)

                    Button {
                        let amt = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? store.balanceInputAmount
                        let refP = Double(refPriceText.replacingOccurrences(of: ",", with: ".")) ?? store.liveMarketPrice
                        var refs = store.marketPrices
                        refs[store.focusTicker] = refP
                        store.syncRevolutBalance(mode: selectedMode, amount: amt, atReferencePrices: refs)
                        dismiss()
                    } label: {
                        Text("Sync & Anchor Balance")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GlassPalette.accentGold))
                    }

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Sync Revolut Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedMode = store.balanceMode
                amountText = String(format: "%.2f", store.balanceInputAmount)
                refPriceText = String(format: "%.2f", store.liveMarketPrice)
            }
        }
    }
}

