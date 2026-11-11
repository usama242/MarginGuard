import SwiftUI

// MARK: - Lightweight Equatable Snapshot Models for Subview Memoization

private struct HeaderSnap: Equatable {
    let focusTicker: String
    let autoRefreshEnabled: Bool
    let isFetchingPrice: Bool
    let lastPriceUpdate: Date
    let isLiveActivityRunning: Bool
}

private struct HeroSnap: Equatable {
    let livePrice: Double
    let weightedBuyEntry: Double
    let firstLiquidationPriceNow: Double
    let finalCascadeLiquidationPriceNow: Double
    let priceDropToFirstStopOut: Double
    let priceDropPercentToFirstStopOut: Double
    let marginLevelRatio: Double
    let grossUnits: Double
    let projectedDays: Int
    let firstLiquidationPriceAfterDays: Double
    let dailyOvernightBurn: Double
    let isSimulated: Bool
    let focusTicker: String
    let unitLabel: String
}

private struct WhatIfSnap: Equatable {
    let isEnabled: Bool
    let side: TradeSide
    let units: Double
    let useLivePriceAsEntry: Bool
    let entryPrice: Double
    let livePrice: Double
    let focusTicker: String
    let unitLabel: String
    let baseWeightedBuyEntry: Double
    let simWeightedBuyEntry: Double
    let baseFirstLiqNow: Double
    let simFirstLiqNow: Double
}

private struct SliderSnap: Equatable {
    let liveMarketPrice: Double
    let projectedHoldingDays: Int
    let autoRefreshEnabled: Bool
    let defaultPrice: Double
    let projectedAdditionalFees: Double
}

private struct MetricsSnap: Equatable {
    let accountValueNow: Double
    let unrealisedPnL: Double
    let availableToInvestNow: Double
    let zeroAvailableMarginPriceNow: Double
    let marginReservedNow: Double
    let grossNotional: Double
    let maintenanceMargin50: Double
    let firstLiquidationPriceNow: Double
}

private struct CascadeSnap: Equatable {
    let stages: [CascadeStageSnap]
    let projectedDays: Int

    struct CascadeStageSnap: Equatable, Identifiable {
        let id: UUID
        let stageIndex: Int
        let title: String
        let closedPositionDescription: String
        let dropFromLivePercent: Double
        let triggerPriceNow: Double
        let triggerPriceAfterDays: Double
        let isCritical: Bool
    }
}

private struct PositionRow: Equatable {
    let id: UUID
    let sideRaw: String
    let isBuy: Bool
    let units: Double
    let unitLabel: String
    let entryPrice: Double
    let leverage: Double
    let margin: Double
    let dailyFee: Double
    let pnl: Double
    let daysHeld: Int
}

private struct PositionsSectionSnap: Equatable {
    let activePositionsCount: Int
    let weightedBuyEntry: Double
    let rows: [PositionRow]
}

// MARK: - 1. Top Header View (Equatable)

private struct TopHeaderView: View, Equatable {
    let snap: HeaderSnap
    let onRefresh: () -> Void
    let onToggleIsland: () -> Void
    let onOpenWizard: () -> Void

    static func == (lhs: TopHeaderView, rhs: TopHeaderView) -> Bool {
        lhs.snap == rhs.snap
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(snap.autoRefreshEnabled ? GlassPalette.safeEmerald : GlassPalette.warningAmber)
                        .frame(width: 8, height: 8)
                    Text(snap.autoRefreshEnabled
                         ? "LIVE 5s • \(Self.timeFormatter.string(from: snap.lastPriceUpdate))"
                         : "MANUAL PRICE MODE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(snap.autoRefreshEnabled ? GlassPalette.safeEmerald : GlassPalette.warningAmber)
                        .tracking(0.8)
                }
                Text("\(snap.focusTicker) Price Guard")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.textPrimary)
            }

            Spacer()

            // Manual Refresh Button
            Button(action: onRefresh) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                        .rotationEffect(.degrees(snap.isFetchingPrice ? 360 : 0))
                        .animation(
                            snap.isFetchingPrice
                                ? .linear(duration: 0.7).repeatForever(autoreverses: false)
                                : .default,
                            value: snap.isFetchingPrice
                        )
                    Text("Refresh")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(Capsule().fill(GlassPalette.accentGold.opacity(0.22)))
                .foregroundStyle(GlassPalette.accentGold)
            }

            // Dynamic Island / Live Activity Toggle
            Button(action: onToggleIsland) {
                HStack(spacing: 4) {
                    Image(systemName: snap.isLiveActivityRunning ? "dot.radiowaves.left.and.right" : "platter.filled.top.iphone")
                        .font(.system(size: 12, weight: .bold))
                    Text(snap.isLiveActivityRunning ? "1m Live" : "Island")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Capsule().fill(
                    snap.isLiveActivityRunning
                        ? GlassPalette.safeEmerald.opacity(0.22)
                        : GlassPalette.glassSurfaceTint
                ))
                .foregroundStyle(snap.isLiveActivityRunning ? GlassPalette.safeEmerald : GlassPalette.textPrimary)
            }

            // Setup / Sync Button
            Button(action: onOpenWizard) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(GlassPalette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(GlassPalette.glassSurfaceTint))
            }
        }
    }
}

// MARK: - 2. Hero Liquidation Card (Equatable, GPU Direct Raster)

private struct HeroCard: View, Equatable {
    let snap: HeroSnap

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE \(snap.focusTicker) MARKET PRICE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("$\(String(format: "%.2f", snap.livePrice))")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(GlassPalette.accentGold)
                        Text("/ \(snap.unitLabel)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GlassPalette.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(snap.isSimulated ? "SIMULATED AVG ENTRY" : "AVERAGE ENTRY PRICE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textSecondary)
                    Text("$\(String(format: "%.2f", snap.weightedBuyEntry))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GlassPalette.textPrimary)
                    let diffToBE = snap.weightedBuyEntry - snap.livePrice
                    Text("Need \(String(format: "%+.2f$", diffToBE))/oz to Break-Even")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
            }

            Divider().opacity(0.25)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("1ST POSITION LIQUIDATES AT GOLD PRICE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.dangerCoral)
                        if snap.isSimulated {
                            Text("SIMULATED")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(GlassPalette.accentGold.opacity(0.25)))
                                .foregroundStyle(GlassPalette.accentGold)
                        }
                    }
                    Text("$\(String(format: "%.2f", snap.firstLiquidationPriceNow))")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GlassPalette.dangerCoral)
                    Text("Gold can drop -$\(String(format: "%.2f", snap.priceDropToFirstStopOut))/oz (\(String(format: "%.1f%%", snap.priceDropPercentToFirstStopOut))) before 50% Stop-Out")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("MARGIN LEVEL")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textSecondary)
                    Text("\(String(format: "%.0f%%", snap.marginLevelRatio * 100))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(statusColor(ratio: snap.marginLevelRatio))
                    Text("\(String(format: "%.1fx", snap.grossUnits)) \(snap.unitLabel) Open")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
            }

            SafetyBarView(snap: snap)

            Divider().opacity(0.25)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("In \(snap.projectedDays)d (With Swap Fees)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GlassPalette.textSecondary)
                    Text("$\(String(format: "%.2f", snap.firstLiquidationPriceAfterDays))/oz")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GlassPalette.warningAmber)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("All Positions Liquidated")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GlassPalette.textSecondary)
                    Text("$\(String(format: "%.2f", snap.finalCascadeLiquidationPriceNow))/oz")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GlassPalette.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Overnight Swap Burn")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GlassPalette.textSecondary)
                    Text("-$\(String(format: "%.2f", snap.dailyOvernightBurn))/d")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GlassPalette.dangerCoral)
                }
            }
        }
        .liquidGlassCard(cornerRadius: 24, padding: 18)
    }

    private func statusColor(ratio: Double) -> Color {
        if ratio <= 0.60 { return GlassPalette.dangerCoral }
        if ratio <= 0.85 { return GlassPalette.warningAmber }
        return GlassPalette.safeEmerald
    }
}

// MARK: - Canvas-Based Safety Bar (GPU Accelerated via Metal)

private struct SafetyBarView: View, Equatable {
    let snap: HeroSnap

    var body: some View {
        let minP = max(0, snap.finalCascadeLiquidationPriceNow * 0.95)
        let maxP = max(snap.weightedBuyEntry, snap.livePrice) * 1.02
        let range = max(1.0, maxP - minP)
        let liveRatio  = CGFloat(min(1.0, max(0.0, (snap.livePrice - minP) / range)))
        let liqRatio   = CGFloat(min(1.0, max(0.0, (snap.firstLiquidationPriceNow - minP) / range)))

        VStack(spacing: 6) {
            Canvas { ctx, size in
                let barRect = CGRect(x: 0, y: 4, width: size.width, height: 8)
                let gradient = Gradient(colors: [
                    GlassPalette.dangerCoral, GlassPalette.warningAmber, GlassPalette.safeEmerald
                ])
                ctx.fill(
                    Path(roundedRect: barRect, cornerRadius: 4),
                    with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 4),
                                                     endPoint: CGPoint(x: size.width, y: 4))
                )

                let liqX = liqRatio * size.width
                let liqCircle = CGRect(x: liqX - 7, y: 0, width: 14, height: 14)
                ctx.fill(Path(ellipseIn: liqCircle), with: .color(.white))
                ctx.fill(Path(ellipseIn: liqCircle.insetBy(dx: 2, dy: 2)), with: .color(GlassPalette.dangerCoral))

                let liveX = liveRatio * size.width
                let liveCircle = CGRect(x: liveX - 8, y: -1, width: 16, height: 16)
                ctx.fill(Path(ellipseIn: liveCircle), with: .color(.white))
                ctx.fill(Path(ellipseIn: liveCircle.insetBy(dx: 2.5, dy: 2.5)), with: .color(GlassPalette.accentGold))
            }
            .frame(height: 16)
            .drawingGroup() // Direct GPU offload

            HStack {
                Text("Stop-Out: $\(String(format: "%.0f", snap.firstLiquidationPriceNow))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.dangerCoral)
                Spacer()
                Text("Live: $\(String(format: "%.2f", snap.livePrice))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)
                Spacer()
                Text("Avg Entry: $\(String(format: "%.2f", snap.weightedBuyEntry))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.safeEmerald)
            }
        }
    }
}

// MARK: - 3. What-If Trade Simulator Card (Equatable)

private struct WhatIfSimulatorCardView: View, Equatable {
    let snap: WhatIfSnap
    let onToggleEnabled: (Bool) -> Void
    let onUpdateSide: (TradeSide) -> Void
    let onUpdateUnits: (Double) -> Void
    let onToggleLiveEntry: (Bool) -> Void
    let onUpdateEntryPrice: (Double) -> Void

    @State private var entryText: String = ""

    static func == (lhs: WhatIfSimulatorCardView, rhs: WhatIfSimulatorCardView) -> Bool {
        lhs.snap == rhs.snap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(GlassPalette.accentGold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("WHAT-IF NEW TRADE SIMULATOR")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                    Text("Test buying/selling more \(snap.focusTicker) without altering your real positions")
                        .font(.system(size: 11))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { snap.isEnabled },
                    set: { onToggleEnabled($0) }
                ))
                .labelsHidden()
                .tint(GlassPalette.accentGold)
            }

            if snap.isEnabled {
                Divider().opacity(0.25)

                HStack(spacing: 10) {
                    Picker("Side", selection: Binding(
                        get: { snap.side },
                        set: { onUpdateSide($0) }
                    )) {
                        ForEach(TradeSide.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)

                    Spacer()

                    Text("Units: \(String(format: "%.2f", snap.units)) \(snap.unitLabel)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)

                    Stepper("", value: Binding(
                        get: { snap.units },
                        set: { onUpdateUnits($0) }
                    ), in: 0.1...20.0, step: 0.25)
                    .labelsHidden()
                }

                Toggle("Enter at Live Price ($\(String(format: "%.2f", snap.livePrice)))",
                       isOn: Binding(
                        get: { snap.useLivePriceAsEntry },
                        set: { onToggleLiveEntry($0) }
                       ))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GlassPalette.textSecondary)
                    .tint(GlassPalette.accentGold)

                if !snap.useLivePriceAsEntry {
                    HStack {
                        Text("Hypothetical Entry ($/oz):")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GlassPalette.textSecondary)
                        Spacer()
                        TextField("4000.00", text: $entryText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.accentGold)
                            .frame(width: 110).padding(6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.15)))
                            .onAppear {
                                entryText = String(format: "%.2f", snap.entryPrice)
                            }
                            .onChange(of: entryText) { _, newVal in
                                if let v = NumberParser.parse(newVal), v > 0 {
                                    onUpdateEntryPrice(v)
                                }
                            }
                    }
                }

                HStack(spacing: 10) {
                    simComparisonBox(
                        title: "Avg Entry Gold Price",
                        before: "$\(String(format: "%.2f", snap.baseWeightedBuyEntry))",
                        after:  "$\(String(format: "%.2f", snap.simWeightedBuyEntry))",
                        delta: snap.simWeightedBuyEntry - snap.baseWeightedBuyEntry,
                        lowerIsBetter: true
                    )
                    simComparisonBox(
                        title: "1st Liquidation Price",
                        before: "$\(String(format: "%.2f", snap.baseFirstLiqNow))",
                        after:  "$\(String(format: "%.2f", snap.simFirstLiqNow))",
                        delta: snap.simFirstLiqNow - snap.baseFirstLiqNow,
                        lowerIsBetter: true
                    )
                }
            }
        }
        .liquidGlassCard(
            cornerRadius: 22, padding: 16,
            tint: snap.isEnabled ? GlassPalette.accentGold.opacity(0.08) : nil
        )
    }

    private func simComparisonBox(title: String, before: String, after: String, delta: Double, lowerIsBetter: Bool) -> some View {
        let isImproved = lowerIsBetter ? (delta <= 0) : (delta >= 0)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(GlassPalette.textSecondary)
            HStack(spacing: 4) {
                Text(before).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(GlassPalette.textSecondary)
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(GlassPalette.accentGold)
                Text(after).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(GlassPalette.textPrimary)
            }
            Text(String(format: "%+.2f$/oz", delta))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isImproved ? GlassPalette.safeEmerald : GlassPalette.dangerCoral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.14)))
    }
}

// MARK: - 4. Interactive Price & Holding Horizon Sliders (Equatable)

private struct InteractivePriceAndHorizonCardView: View, Equatable {
    let snap: SliderSnap
    let onPriceChange: (Double) -> Void
    let onDaysChange: (Int) -> Void
    let onResumeLive: () -> Void

    static func == (lhs: InteractivePriceAndHorizonCardView, rhs: InteractivePriceAndHorizonCardView) -> Bool {
        lhs.snap == rhs.snap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Test Gold Market Price ($/oz)", systemImage: "dial.medium.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.textPrimary)
                Spacer()
                if !snap.autoRefreshEnabled {
                    Button("Resume Live 5s", action: onResumeLive)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(GlassPalette.safeEmerald.opacity(0.2)))
                        .foregroundStyle(GlassPalette.safeEmerald)
                }
                Text("$\(String(format: "%.2f", snap.liveMarketPrice))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(GlassPalette.accentGold)
            }

            Slider(
                value: Binding(
                    get: { snap.liveMarketPrice },
                    set: { onPriceChange($0) }
                ),
                in: max(500, snap.defaultPrice * 0.45)...(snap.defaultPrice * 1.25),
                step: 1.0
            )
            .tint(GlassPalette.accentGold)

            HStack {
                Label("Holding Horizon (Overnight Swap Projection)", systemImage: "moon.stars.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.textPrimary)
                Spacer()
                Text("\(snap.projectedHoldingDays)d (-$\(String(format: "%.1f", snap.projectedAdditionalFees)))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(GlassPalette.warningAmber)
            }

            Slider(
                value: Binding(
                    get: { Double(snap.projectedHoldingDays) },
                    set: { onDaysChange(Int($0)) }
                ),
                in: 0...180,
                step: 5
            )
            .tint(GlassPalette.warningAmber)
        }
        .liquidGlassCard(cornerRadius: 22, padding: 16)
    }
}

// MARK: - 5. Revolut Metrics Grid (Equatable, Non-Lazy Direct 2x2 Layout)

private struct MetricsGridView: View, Equatable {
    let snap: MetricsSnap

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricTile(
                    title: "Account Value (Equity)",
                    value: "$\(String(format: "%.2f", snap.accountValueNow))",
                    subtitle: "Unrealized P&L: \(String(format: "%+.2f$", snap.unrealisedPnL))",
                    icon: "building.columns.fill",
                    accent: snap.unrealisedPnL >= 0 ? GlassPalette.safeEmerald : GlassPalette.dangerCoral
                )
                metricTile(
                    title: "Available to Invest",
                    value: "$\(String(format: "%.2f", snap.availableToInvestNow))",
                    subtitle: "Free Margin @ $\(String(format: "%.0f", snap.zeroAvailableMarginPriceNow))/oz",
                    icon: "sparkles.rectangle.stack.fill",
                    accent: snap.availableToInvestNow >= 0 ? GlassPalette.safeEmerald : GlassPalette.dangerCoral
                )
            }
            HStack(spacing: 12) {
                metricTile(
                    title: "Margin Reserved (100%)",
                    value: "$\(String(format: "%.2f", snap.marginReservedNow))",
                    subtitle: "Exposure: $\(String(format: "%.2f", snap.grossNotional))",
                    icon: "lock.shield.fill",
                    accent: GlassPalette.accentGold
                )
                metricTile(
                    title: "Maint. Margin (50%)",
                    value: "$\(String(format: "%.2f", snap.maintenanceMargin50))",
                    subtitle: "1st Liq @ $\(String(format: "%.2f", snap.firstLiquidationPriceNow))/oz",
                    icon: "exclamationmark.triangle.fill",
                    accent: GlassPalette.warningAmber
                )
            }
        }
    }

    private func metricTile(title: String, value: String, subtitle: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
            }
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(GlassPalette.textPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(GlassPalette.textSecondary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.95))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 18, padding: 14)
    }
}

// MARK: - 6. Cascade Ladder (Equatable)

private struct CascadeLadderView: View, Equatable {
    let snap: CascadeSnap

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GOLD PRICE LIQUIDATION LADDER ($/OZ)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                        .tracking(0.8)
                    Text("Exact Gold prices where Revolut liquidates each position")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
                Spacer()
            }

            ForEach(snap.stages) { stage in
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(stage.isCritical
                              ? GlassPalette.dangerCoral.opacity(0.22)
                              : GlassPalette.warningAmber.opacity(0.22))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("\(stage.stageIndex)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(stage.isCritical ? GlassPalette.dangerCoral : GlassPalette.warningAmber)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.textPrimary)
                        Text("\(stage.closedPositionDescription) (\(String(format: "%.1f%%", stage.dropFromLivePercent)))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(GlassPalette.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(String(format: "%.2f", stage.triggerPriceNow))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(stage.isCritical ? GlassPalette.dangerCoral : GlassPalette.warningAmber)
                        Text("In \(snap.projectedDays)d: $\(String(format: "%.2f", stage.triggerPriceAfterDays))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(GlassPalette.textSecondary)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .liquidGlassCard(cornerRadius: 22, padding: 16)
    }
}

// MARK: - 7. Open Positions Section (Equatable)

private struct PositionRowView: View, Equatable {
    let row: PositionRow
    let onTap: () -> Void

    static func == (lhs: PositionRowView, rhs: PositionRowView) -> Bool {
        lhs.row == rhs.row
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(row.sideRaw)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Capsule().fill(
                        row.isBuy
                            ? GlassPalette.safeEmerald.opacity(0.2)
                            : GlassPalette.dangerCoral.opacity(0.2)
                    ))
                    .foregroundStyle(row.isBuy ? GlassPalette.safeEmerald : GlassPalette.dangerCoral)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(format: "%.2f", row.units)) \(row.unitLabel) @ $\(String(format: "%.2f", row.entryPrice))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)
                    Text("\(Int(row.leverage))x • Margin: $\(String(format: "%.2f", row.margin)) • Swap: -$\(String(format: "%.2f", row.dailyFee))/d")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GlassPalette.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%+.2f$", row.pnl))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(row.pnl >= 0 ? GlassPalette.safeEmerald : GlassPalette.dangerCoral)
                    Text("Tap to edit")
                        .font(.system(size: 10))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
            }
            .liquidGlassCard(cornerRadius: 18, padding: 13)
        }
        .buttonStyle(.plain)
    }
}

private struct OpenPositionsSectionView: View, Equatable {
    let snap: PositionsSectionSnap
    let onAddSync: () -> Void
    let onEditPosition: (UUID) -> Void

    static func == (lhs: OpenPositionsSectionView, rhs: OpenPositionsSectionView) -> Bool {
        lhs.snap == rhs.snap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR POSITIONS (\(snap.activePositionsCount) ACTIVE • AVG $\(String(format: "%.2f", snap.weightedBuyEntry)))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.textSecondary)
                    .tracking(0.6)
                Spacer()
                Button(action: onAddSync) {
                    Label("Add / Sync", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                }
            }

            ForEach(snap.rows, id: \.id) { row in
                PositionRowView(row: row) {
                    onEditPosition(row.id)
                }
                .equatable()
            }
        }
    }
}

// MARK: - Main Dashboard View Container

public struct DashboardView: View {
    @ObservedObject var store: PortfolioStore
    @State private var showWizardSheet: Bool = false
    @State private var editingPosition: CFDPosition? = nil
    @State private var editUnitsText: String = ""
    @State private var editEntryText: String = ""

    public init(store: PortfolioStore) {
        self.store = store
    }

    public var body: some View {
        let activeSnap = store.activeAnalytics
        let baseSnap   = store.analytics
        let simSnap    = store.simulatedAnalytics

        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // 1. Top Header
                TopHeaderView(
                    snap: makeHeaderSnap(),
                    onRefresh: {
                        store.autoRefreshEnabled = true
                        Task { await store.refreshMarketPricesNow(isBackgroundTick: false) }
                    },
                    onToggleIsland: { store.toggleLiveActivity() },
                    onOpenWizard: { showWizardSheet = true }
                ).equatable()

                // 2. Hero Card (Equatable)
                HeroCard(snap: makeHeroSnap(activeSnap)).equatable()

                // 3. What-If Simulator (Equatable)
                WhatIfSimulatorCardView(
                    snap: makeWhatIfSnap(base: baseSnap, sim: simSnap),
                    onToggleEnabled: { store.simulatedTrade.isEnabled = $0 },
                    onUpdateSide: { store.simulatedTrade.side = $0 },
                    onUpdateUnits: { store.simulatedTrade.units = $0 },
                    onToggleLiveEntry: { store.simulatedTrade.useLivePriceAsEntry = $0 },
                    onUpdateEntryPrice: { store.simulatedTrade.entryPrice = $0 }
                ).equatable()

                // 4. Live Price & Horizon Sliders (Equatable)
                InteractivePriceAndHorizonCardView(
                    snap: makeSliderSnap(activeSnap),
                    onPriceChange: { newVal in
                        store.autoRefreshEnabled = false
                        store.liveMarketPrice = newVal
                    },
                    onDaysChange: { store.projectedHoldingDays = $0 },
                    onResumeLive: {
                        store.autoRefreshEnabled = true
                        Task { await store.refreshMarketPricesNow() }
                    }
                ).equatable()

                // 5. Revolut Metrics Grid (Equatable, Non-Lazy Grid)
                MetricsGridView(snap: makeMetricsSnap(activeSnap)).equatable()

                // 6. Cascade Ladder (Equatable)
                CascadeLadderView(snap: makeCascadeSnap(activeSnap)).equatable()

                // 7. Open Positions (Equatable)
                OpenPositionsSectionView(
                    snap: makePositionsSnap(base: baseSnap),
                    onAddSync: { showWizardSheet = true },
                    onEditPosition: { posId in
                        if let pos = store.positions.first(where: { $0.id == posId }) {
                            editUnitsText = String(format: "%.2f", pos.units)
                            editEntryText = String(format: "%.2f", pos.entryPrice)
                            editingPosition = pos
                        }
                    }
                ).equatable()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showWizardSheet) {
            OnboardingWizardView(store: store)
        }
        .sheet(item: $editingPosition) { pos in
            positionQuickEditSheet(position: pos)
                .presentationDetents([.height(300)])
        }
    }

    // MARK: - Snapshot Builders

    private func makeHeaderSnap() -> HeaderSnap {
        HeaderSnap(
            focusTicker: store.focusTicker,
            autoRefreshEnabled: store.autoRefreshEnabled,
            isFetchingPrice: store.isFetchingPrice,
            lastPriceUpdate: store.lastPriceUpdate,
            isLiveActivityRunning: store.isLiveActivityRunning
        )
    }

    private func makeHeroSnap(_ s: PortfolioAnalytics) -> HeroSnap {
        HeroSnap(
            livePrice: s.livePrice,
            weightedBuyEntry: s.weightedBuyEntry,
            firstLiquidationPriceNow: s.firstLiquidationPriceNow,
            finalCascadeLiquidationPriceNow: s.finalCascadeLiquidationPriceNow,
            priceDropToFirstStopOut: s.priceDropToFirstStopOut,
            priceDropPercentToFirstStopOut: s.priceDropPercentToFirstStopOut,
            marginLevelRatio: s.marginLevelRatio,
            grossUnits: s.grossUnits,
            projectedDays: s.projectedDays,
            firstLiquidationPriceAfterDays: s.firstLiquidationPriceAfterDays,
            dailyOvernightBurn: s.dailyOvernightBurn,
            isSimulated: store.simulatedTrade.isEnabled,
            focusTicker: s.focusTicker,
            unitLabel: store.selectedPreset.unitLabel
        )
    }

    private func makeWhatIfSnap(base: PortfolioAnalytics, sim: PortfolioAnalytics) -> WhatIfSnap {
        WhatIfSnap(
            isEnabled: store.simulatedTrade.isEnabled,
            side: store.simulatedTrade.side,
            units: store.simulatedTrade.units,
            useLivePriceAsEntry: store.simulatedTrade.useLivePriceAsEntry,
            entryPrice: store.simulatedTrade.entryPrice,
            livePrice: store.liveMarketPrice,
            focusTicker: base.focusTicker,
            unitLabel: store.selectedPreset.unitLabel,
            baseWeightedBuyEntry: base.weightedBuyEntry,
            simWeightedBuyEntry: sim.weightedBuyEntry,
            baseFirstLiqNow: base.firstLiquidationPriceNow,
            simFirstLiqNow: sim.firstLiquidationPriceNow
        )
    }

    private func makeSliderSnap(_ s: PortfolioAnalytics) -> SliderSnap {
        SliderSnap(
            liveMarketPrice: store.liveMarketPrice,
            projectedHoldingDays: store.projectedHoldingDays,
            autoRefreshEnabled: store.autoRefreshEnabled,
            defaultPrice: store.selectedPreset.defaultPrice,
            projectedAdditionalFees: s.projectedAdditionalFees
        )
    }

    private func makeMetricsSnap(_ s: PortfolioAnalytics) -> MetricsSnap {
        MetricsSnap(
            accountValueNow: s.accountValueNow,
            unrealisedPnL: s.unrealisedPnL,
            availableToInvestNow: s.availableToInvestNow,
            zeroAvailableMarginPriceNow: s.zeroAvailableMarginPriceNow,
            marginReservedNow: s.marginReservedNow,
            grossNotional: s.grossNotional,
            maintenanceMargin50: s.maintenanceMargin50,
            firstLiquidationPriceNow: s.firstLiquidationPriceNow
        )
    }

    private func makeCascadeSnap(_ s: PortfolioAnalytics) -> CascadeSnap {
        CascadeSnap(
            stages: s.cascadeStages.map {
                CascadeSnap.CascadeStageSnap(
                    id: $0.id,
                    stageIndex: $0.stageIndex,
                    title: $0.title,
                    closedPositionDescription: $0.closedPositionDescription,
                    dropFromLivePercent: $0.dropFromLivePercent,
                    triggerPriceNow: $0.triggerPriceNow,
                    triggerPriceAfterDays: $0.triggerPriceAfterDays,
                    isCritical: $0.isCritical
                )
            },
            projectedDays: s.projectedDays
        )
    }

    private func makePositionsSnap(base: PortfolioAnalytics) -> PositionsSectionSnap {
        let livePrice = store.liveMarketPrice
        let unitLabel = store.selectedPreset.unitLabel
        let rows: [PositionRow] = store.positions.map { pos in
            PositionRow(
                id: pos.id,
                sideRaw: pos.side.rawValue,
                isBuy: pos.side == .buy,
                units: pos.units,
                unitLabel: unitLabel,
                entryPrice: pos.entryPrice,
                leverage: pos.leverage,
                margin: pos.liveMarginReserved(at: livePrice),
                dailyFee: pos.dailyOvernightFee(at: livePrice),
                pnl: pos.grossPnL(at: livePrice),
                daysHeld: pos.daysHeld
            )
        }
        return PositionsSectionSnap(
            activePositionsCount: base.activePositionsCount,
            weightedBuyEntry: base.weightedBuyEntry,
            rows: rows
        )
    }

    // MARK: - Quick Edit Position Sheet

    private func positionQuickEditSheet(position: CFDPosition) -> some View {
        ZStack {
            LiquidGlassBackground()
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Position (\(position.ticker))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.textPrimary)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Entry Price ($)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GlassPalette.textSecondary)
                        TextField("4554.98", text: $editEntryText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.textPrimary)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.15)))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Units (\(store.selectedPreset.unitLabel))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GlassPalette.textSecondary)
                        TextField("0.50", text: $editUnitsText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.textPrimary)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.15)))
                    }
                }

                HStack(spacing: 12) {
                    Button("Delete Position") {
                        store.positions.removeAll { $0.id == position.id }
                        editingPosition = nil
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.dangerCoral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(GlassPalette.dangerCoral.opacity(0.16)))

                    Button("Save Changes") {
                        if let idx = store.positions.firstIndex(where: { $0.id == position.id }) {
                            if let e = NumberParser.parse(editEntryText), e > 0 {
                                store.positions[idx].entryPrice = e
                            }
                            if let u = NumberParser.parse(editUnitsText), u > 0 {
                                store.positions[idx].units = u
                            }
                        }
                        editingPosition = nil
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(GlassPalette.accentGold))
                }
            }
            .padding(22)
        }
    }
}
