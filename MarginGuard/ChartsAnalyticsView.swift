import SwiftUI
import Charts

// MARK: - High-Clarity Bar Diagrams with Tight Vertical Scaling & What-If Simulation
public struct ChartsAnalyticsView: View {
    @ObservedObject var store: PortfolioStore
    @State private var creepChartMode: Int = 0 // 0 = Zoomed Stop-Out Price ($/oz), 1 = Price Creep (+$/oz)

    public init(store: PortfolioStore) {
        self.store = store
    }

    public var body: some View {
        let baseSnap = store.analytics
        let simSnap  = store.simulatedAnalytics
        let activeSnap = store.activeAnalytics

        let milestoneBars = CFDEngine.buildMilestoneBars(
            base: baseSnap,
            simulated: simSnap,
            includeSimulation: store.simulatedTrade.isEnabled
        )
        let creepBars = CFDEngine.buildOvernightCreepBars(analytics: activeSnap)
        let sizeBars = CFDEngine.buildSizeComparisonBars(
            positions: store.positions,
            focusTicker: store.focusTicker,
            livePrice: store.liveMarketPrice,
            settledCashBaseline: store.settledCashBaseline,
            projectedDays: store.projectedHoldingDays,
            simEntryPrice: store.simulatedTrade.useLivePriceAsEntry ? store.liveMarketPrice : store.simulatedTrade.entryPrice,
            simSide: store.simulatedTrade.side
        )

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Header + Quick What-If Simulation Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GOLD PRICE & LIQUIDATION CHARTS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.accentGold)
                            .tracking(1.0)
                        Text("Bar Diagrams & What-If Impact")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.textPrimary)
                    }
                    Spacer()
                    Toggle("Sim", isOn: $store.simulatedTrade.isEnabled)
                        .labelsHidden()
                        .tint(GlassPalette.accentGold)
                }

                // Inline Quick Simulator Control Bar on Charts Tab
                quickSimControlBar(base: baseSnap, sim: simSnap)

                // CHART 1: Gold Price Structure Bar Diagram (Avg Entry vs Live vs Stop-Outs)
                goldMilestoneBarChart(bars: milestoneBars, base: baseSnap)

                // CHART 2: Overnight Fee Impact Bar Diagram (Zoomed Y-Axis so Creep is Crystal Clear)
                overnightCreepBarChart(bars: creepBars, snap: activeSnap)

                // CHART 3: What-If Additional Position Size Comparison Bar Chart (+0.5 oz to +2.0 oz)
                whatIfSizeBarChart(bars: sizeBars)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Inline Simulation Bar for Charts
    private func quickSimControlBar(base: PortfolioAnalytics, sim: PortfolioAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(GlassPalette.accentGold)
                Text(store.simulatedTrade.isEnabled
                     ? "Comparing Current Portfolio vs. +\(String(format: "%.2f", store.simulatedTrade.units)) oz \(store.simulatedTrade.side.rawValue)"
                     : "Toggle ON to overlay a simulated Gold trade on the charts")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GlassPalette.textPrimary)
                Spacer()
            }

            if store.simulatedTrade.isEnabled {
                HStack {
                    Text("Sim Size: \(String(format: "%.2f", store.simulatedTrade.units)) oz")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                    Slider(value: $store.simulatedTrade.units, in: 0.25...5.0, step: 0.25)
                        .tint(GlassPalette.accentGold)
                    Text("Liq: $\(String(format: "%.0f", sim.firstLiquidationPriceNow))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.dangerCoral)
                }
            }
        }
        .liquidGlassCard(cornerRadius: 18, padding: 14)
    }

    // MARK: - CHART 1: Gold Price Milestones Bar Diagram
    private func goldMilestoneBarChart(bars: [PriceMilestoneBar], base: PortfolioAnalytics) -> some View {
        let prices = bars.map { $0.goldPrice }.filter { $0 > 0 }
        let minP = max(0, (prices.min() ?? 1500) * 0.82)
        let maxP = (prices.max() ?? 4800) * 1.12

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("1. GOLD PRICE MILESTONES BAR DIAGRAM ($/OZ)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)
                Text("Compares your Average Entry, Live Gold Price, Margin Call, and 50% Stop-Out Gold Prices")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassPalette.textSecondary)
            }

            Chart(bars) { item in
                BarMark(
                    x: .value("Milestone", item.shortLabel),
                    yStart: .value("Base", minP),
                    yEnd: .value("Gold Price", item.goldPrice),
                    width: store.simulatedTrade.isEnabled ? .fixed(18) : .fixed(32)
                )
                .foregroundStyle(by: .value("Scenario", item.scenario))
                .position(by: .value("Scenario", item.scenario))
                .cornerRadius(6)
                .annotation(position: .top, alignment: .center) {
                    Text("$\(Int(round(item.goldPrice)))")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)
                }
            }
            .chartYScale(domain: minP...maxP)
            .chartForegroundStyleScale([
                "Current": GlassPalette.safeEmerald,
                "Simulated": GlassPalette.accentGold
            ])
            .frame(height: 235)
        }
        .liquidGlassCard(cornerRadius: 22, padding: 16)
    }

    // MARK: - CHART 2: Overnight Fee Liquidation Creep Bar Diagram (Zoomed Scale!)
    private func overnightCreepBarChart(bars: [OvernightCreepBar], snap: PortfolioAnalytics) -> some View {
        let minStop = (bars.map { $0.stopOutGoldPrice }.min() ?? 1800) - 18.0
        let maxStop = (bars.map { $0.stopOutGoldPrice }.max() ?? 1950) + 28.0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("2. OVERNIGHT FEE CREEP ON LIQUIDATION PRICE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                    Text("Zoomed vertical scale showing exact $/oz rise in your 50% Liquidation Price over time")
                        .font(.system(size: 12))
                        .foregroundStyle(GlassPalette.textSecondary)
                }
                Spacer()
            }

            Picker("View Mode", selection: $creepChartMode) {
                Text("Zoomed Stop-Out ($/oz)").tag(0)
                Text("Swap Fee Burn ($)").tag(1)
            }
            .pickerStyle(.segmented)

            if creepChartMode == 0 {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Horizon", bar.label),
                        yStart: .value("Min", minStop),
                        yEnd: .value("Stop-Out Price", bar.stopOutGoldPrice),
                        width: .fixed(28)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GlassPalette.dangerCoral, GlassPalette.warningAmber],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        VStack(spacing: 1) {
                            Text("$\(String(format: "%.0f", bar.stopOutGoldPrice))")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(GlassPalette.textPrimary)
                            if bar.priceCreepDollars > 0 {
                                Text("+$\(String(format: "%.0f", bar.priceCreepDollars))")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(GlassPalette.warningAmber)
                            }
                        }
                    }
                }
                .chartYScale(domain: minStop...maxStop)
                .frame(height: 225)
            } else {
                Chart(bars.filter { $0.day > 0 }) { bar in
                    BarMark(
                        x: .value("Horizon", bar.label),
                        y: .value("Cumulative Swap Fee ($)", bar.cumulativeSwapFee),
                        width: .fixed(30)
                    )
                    .foregroundStyle(GlassPalette.dangerCoral.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text("-$\(String(format: "%.0f", bar.cumulativeSwapFee))")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.dangerCoral)
                    }
                }
                .frame(height: 225)
            }

            HStack {
                Text("Daily Liquidation Creep: +$\(String(format: "%.2f", abs(snap.dailyLiquidationPriceDrift)))/oz per day")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(GlassPalette.warningAmber)
                Spacer()
                Text("Daily Swap: -$\(String(format: "%.2f", snap.dailyOvernightBurn))/d")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(GlassPalette.dangerCoral)
            }
        }
        .liquidGlassCard(cornerRadius: 22, padding: 16)
    }

    // MARK: - CHART 3: What-If Trade Size Comparison Bar Diagram
    private func whatIfSizeBarChart(bars: [SizeSimulationBar]) -> some View {
        let allPrices = bars.map { $0.goldPrice }.filter { $0 > 0 }
        let minP = max(0, (allPrices.min() ?? 1500) * 0.80)
        let maxP = (allPrices.max() ?? 4800) * 1.12

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("3. WHAT-IF POSITION SIZE IMPACT BAR CHART")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)
                Text("How adding +0.5 oz to +2.0 oz lowers Break-Even Gold Price vs. raises 50% Stop-Out Gold Price")
                    .font(.system(size: 12))
                    .foregroundStyle(GlassPalette.textSecondary)
            }

            Chart(bars) { bar in
                BarMark(
                    x: .value("Added Size", bar.addedUnitsLabel),
                    yStart: .value("Base", minP),
                    yEnd: .value("Gold Price", bar.goldPrice),
                    width: .fixed(22)
                )
                .foregroundStyle(by: .value("Metric", bar.metric))
                .position(by: .value("Metric", bar.metric))
                .cornerRadius(5)
                .annotation(position: .top) {
                    Text("$\(Int(round(bar.goldPrice)))")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.textPrimary)
                }
            }
            .chartYScale(domain: minP...maxP)
            .chartForegroundStyleScale([
                "Break-Even Gold Price": GlassPalette.safeEmerald,
                "50% Liquidation Gold Price": GlassPalette.dangerCoral
            ])
            .frame(height: 235)
        }
        .liquidGlassCard(cornerRadius: 22, padding: 16)
    }
}
