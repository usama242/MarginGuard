import Foundation

// MARK: - Complete Revolut CFD Portfolio & Commodity-Price Liquidation Engine
public struct PortfolioAnalytics: Equatable {
    public let focusTicker: String
    public let livePrice: Double
    public let projectedDays: Int

    // Core Revolut Account Metrics (Matches Revolut Balances & CFDs screen 1:1)
    public let settledCashBaseline: Double
    public let accountValueNow: Double
    public let grossNotional: Double
    public let marginReservedNow: Double
    public let maintenanceMargin50: Double
    public let availableToInvestNow: Double
    public let marginLevelRatio: Double // e.g. 11.2158 = 1122%

    // P&L & Overnight Financing Metrics
    public let unrealisedPnL: Double
    public let dailyOvernightBurn: Double
    public let projectedAdditionalFees: Double

    // Net Exposure & Commodity Entry Metrics
    public let activePositionsCount: Int
    public let totalBuyUnits: Double
    public let totalSellUnits: Double
    public let netSignedUnits: Double        // Q_net = Buy - Sell
    public let grossUnits: Double            // Q_gross = Buy + Sell
    public let leverageWeightedUnits: Double // Q_eff = sum(Q_i / Lev_i)
    public let weightedBuyEntry: Double
    public let weightedSellEntry: Double
    public let netBreakEvenPriceNow: Double
    public let netBreakEvenPriceAfterDays: Double

    // Dynamic Gold / Commodity Threshold Prices ($/oz) Today vs After t Holding Days
    public let zeroAvailableMarginPriceNow: Double     // 100% Margin Level (Free Margin = $0)
    public let firstMarginCallPriceNow: Double         // 80% Margin Level
    public let secondMarginCallPriceNow: Double        // 60% Margin Level
    public let firstLiquidationPriceNow: Double        // 50% Stop-Out (1st Leg Closed)
    public let finalCascadeLiquidationPriceNow: Double // 50% Stop-Out (Last Leg Closed)
    public let zeroEquityWipeoutPriceNow: Double       // $0 Equity Left

    public let firstMarginCallPriceAfterDays: Double
    public let secondMarginCallPriceAfterDays: Double
    public let firstLiquidationPriceAfterDays: Double
    public let finalCascadeLiquidationPriceAfterDays: Double
    public let zeroEquityWipeoutPriceAfterDays: Double

    // Commodity Price Buffers ($/oz and %)
    public let priceDropToFirstStopOut: Double      // Live Price - 1st Liquidation Price ($/oz)
    public let priceDropPercentToFirstStopOut: Double
    public let cashBufferAboveStopOut: Double
    public let dailyLiquidationPriceDrift: Double   // How much $/oz stop-out rises per day
    public let maxSurvivalDaysAtFlatPrice: Double
    public let cascadeStages: [CascadeStage]

    public var statusText: String {
        guard marginReservedNow > 0 else { return "NO OPEN POSITIONS" }
        if marginLevelRatio <= 0.50 { return "FORCE LIQUIDATION (<50%)" }
        if marginLevelRatio <= 0.60 { return "2ND MARGIN CALL (<60%)" }
        if marginLevelRatio <= 0.80 { return "1ST MARGIN CALL (<80%)" }
        if marginLevelRatio < 1.00  { return "MARGIN BUFFER (<100%)" }
        return "HEALTHY (\(Int(round(marginLevelRatio * 100)))%)"
    }

    /// A zero-state analytics snapshot used as a placeholder before the first real computation.
    public static let empty = PortfolioAnalytics(
        focusTicker: "XAU/USD", livePrice: 0, projectedDays: 30,
        settledCashBaseline: 0, accountValueNow: 0, grossNotional: 0,
        marginReservedNow: 0, maintenanceMargin50: 0, availableToInvestNow: 0,
        marginLevelRatio: 1.0, unrealisedPnL: 0, dailyOvernightBurn: 0,
        projectedAdditionalFees: 0, activePositionsCount: 0,
        totalBuyUnits: 0, totalSellUnits: 0, netSignedUnits: 0,
        grossUnits: 0, leverageWeightedUnits: 0, weightedBuyEntry: 0,
        weightedSellEntry: 0, netBreakEvenPriceNow: 0, netBreakEvenPriceAfterDays: 0,
        zeroAvailableMarginPriceNow: 0, firstMarginCallPriceNow: 0,
        secondMarginCallPriceNow: 0, firstLiquidationPriceNow: 0,
        finalCascadeLiquidationPriceNow: 0, zeroEquityWipeoutPriceNow: 0,
        firstMarginCallPriceAfterDays: 0, secondMarginCallPriceAfterDays: 0,
        firstLiquidationPriceAfterDays: 0, finalCascadeLiquidationPriceAfterDays: 0,
        zeroEquityWipeoutPriceAfterDays: 0, priceDropToFirstStopOut: 0,
        priceDropPercentToFirstStopOut: 0, cashBufferAboveStopOut: 0,
        dailyLiquidationPriceDrift: 0, maxSurvivalDaysAtFlatPrice: 0,
        cascadeStages: []
    )
}

public struct CascadeStage: Identifiable, Equatable {
    public let id = UUID()
    public let stageIndex: Int
    public let title: String
    public let subtitle: String
    public let closedPositionDescription: String
    public let triggerPriceNow: Double
    public let triggerPriceAfterDays: Double
    public let dropFromLivePercent: Double
    public let remainingUnitsAfter: Double
    public let isCritical: Bool
}

// MARK: - Chart Data Models for Bar & Step Diagrams
public struct PriceMilestoneBar: Identifiable {
    public var id: String { "\(label)-\(scenario)" }
    public let label: String
    public let shortLabel: String
    public let scenario: String // "Current" or "Simulated"
    public let goldPrice: Double
    public let category: String
}

public struct OvernightCreepBar: Identifiable {
    public var id: String { label }
    public let day: Int
    public let label: String
    public let stopOutGoldPrice: Double
    public let finalCascadeGoldPrice: Double
    public let priceCreepDollars: Double
    public let cumulativeSwapFee: Double
}

public struct SizeSimulationBar: Identifiable {
    public var id: String { "\(addedUnitsLabel)-\(metric)" }
    public let addedUnits: Double
    public let addedUnitsLabel: String
    public let metric: String // "Avg Entry ($/oz)" or "1st Stop-Out ($/oz)"
    public let goldPrice: Double
}

public enum CFDEngine {

    /// Solves the exact Revolut dynamic threshold price P(alpha, feeAdd)
    /// where Equity(P) - feeAdd = alpha * MarginReserved(P)
    public static func solveThresholdPrice(
        alpha: Double,
        netUnits: Double,
        effUnits: Double,
        livePrice: Double,
        currentEquity: Double,
        additionalFee: Double
    ) -> Double {
        let denominator = netUnits - alpha * effUnits
        guard abs(denominator) > 1e-6 else { return 0 }
        let numerator = (netUnits * livePrice) - currentEquity + additionalFee
        return max(0, numerator / denominator)
    }

    /// Evaluates full portfolio analytics from anchored settledCashBaseline
    public static func evaluate(
        positions: [CFDPosition],
        focusTicker: String,
        livePrice: Double,
        settledCashBaseline: Double,
        projectedDays: Int,
        simulatedTrade: SimulatedTradeConfig? = nil
    ) -> PortfolioAnalytics {
        var active = positions.filter { $0.isActive && $0.units > 0 }

        // If non-destructive simulation is active, append the virtual position leg
        if let sim = simulatedTrade, sim.isEnabled, sim.units > 0 {
            let simEntry = sim.useLivePriceAsEntry ? livePrice : sim.entryPrice
            let defaultLev = active.first?.leverage ?? 20.0
            let defaultRate = active.first?.annualOvernightRate ?? 0.075
            let virtualLeg = CFDPosition(
                ticker: focusTicker,
                side: sim.side,
                units: sim.units,
                entryPrice: simEntry,
                leverage: defaultLev,
                annualOvernightRate: defaultRate,
                daysHeld: 0,
                isActive: true
            )
            active.append(virtualLeg)
        }

        var grossNotional = 0.0
        var marginReserved = 0.0
        var unrealisedPnL = 0.0
        var dailyBurn = 0.0

        var buyUnits = 0.0
        var sellUnits = 0.0
        var buyEntryNotional = 0.0
        var sellEntryNotional = 0.0
        var effUnits = 0.0

        for pos in active {
            let notional = pos.currentNotional(at: livePrice)
            let mr = pos.liveMarginReserved(at: livePrice)
            let pnl = pos.grossPnL(at: livePrice)
            let burn = pos.dailyOvernightFee(at: livePrice)

            grossNotional += notional
            marginReserved += mr
            unrealisedPnL += pnl
            dailyBurn += burn

            if pos.leverage > 0 {
                effUnits += pos.units / pos.leverage
            }
            if pos.side == .buy {
                buyUnits += pos.units
                buyEntryNotional += pos.entryNotional()
            } else {
                sellUnits += pos.units
                sellEntryNotional += pos.entryNotional()
            }
        }

        let maintenance50 = marginReserved * 0.50

        // Dynamic Account Value moves dollar-for-dollar with live Unrealized P&L
        let accountValueNow = max(0, settledCashBaseline + unrealisedPnL)
        let availableToInvestNow = accountValueNow - marginReserved
        let marginLevelRatio = marginReserved > 0 ? (accountValueNow / marginReserved) : 0.0

        let netSignedUnits = buyUnits - sellUnits
        let grossUnits = buyUnits + sellUnits
        let weightedBuy = buyUnits > 0 ? (buyEntryNotional / buyUnits) : 0.0
        let weightedSell = sellUnits > 0 ? (sellEntryNotional / sellUnits) : 0.0

        let projectedFeeAdd = dailyBurn * Double(projectedDays)

        let netBreakEvenNow: Double
        let netBreakEvenAfterDays: Double
        if abs(netSignedUnits) > 1e-6 {
            netBreakEvenNow = max(0, (buyEntryNotional - sellEntryNotional) / netSignedUnits)
            netBreakEvenAfterDays = max(0, (buyEntryNotional - sellEntryNotional + projectedFeeAdd) / netSignedUnits)
        } else {
            netBreakEvenNow = 0
            netBreakEvenAfterDays = 0
        }

        // Dynamic Gold Threshold Prices Today
        let p100Now = solveThresholdPrice(alpha: 1.00, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: 0)
        let p80Now  = solveThresholdPrice(alpha: 0.80, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: 0)
        let p60Now  = solveThresholdPrice(alpha: 0.60, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: 0)
        let p50Now  = solveThresholdPrice(alpha: 0.50, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: 0)
        let p0Now   = solveThresholdPrice(alpha: 0.00, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: 0)

        // Dynamic Gold Threshold Prices After Projected Holding Days
        let p80After = solveThresholdPrice(alpha: 0.80, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: projectedFeeAdd)
        let p60After = solveThresholdPrice(alpha: 0.60, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: projectedFeeAdd)
        let p50After = solveThresholdPrice(alpha: 0.50, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: projectedFeeAdd)
        let p0After  = solveThresholdPrice(alpha: 0.00, netUnits: netSignedUnits, effUnits: effUnits, livePrice: livePrice, currentEquity: accountValueNow, additionalFee: projectedFeeAdd)

        let cascade = simulateSequentialCascade(
            activePositions: active,
            livePrice: livePrice,
            accountValueNow: accountValueNow,
            projectedFeeAdd: projectedFeeAdd,
            p80Now: p80Now,
            p80After: p80After
        )

        let finalCascadeNow = cascade.last?.triggerPriceNow ?? p50Now
        let finalCascadeAfter = cascade.last?.triggerPriceAfterDays ?? p50After

        let priceDrop = max(0, livePrice - p50Now)
        let priceDropPct = livePrice > 0 ? ((p50Now - livePrice) / livePrice) * 100.0 : 0.0

        let cashBuffer = max(0, accountValueNow - maintenance50)
        let denom50 = netSignedUnits - 0.50 * effUnits
        let dailyDrift = abs(denom50) > 1e-6 ? (dailyBurn / denom50) : 0.0
        let maxSurvivalDays = dailyBurn > 0 ? max(0, cashBuffer / dailyBurn) : 9999.0

        return PortfolioAnalytics(
            focusTicker: focusTicker,
            livePrice: livePrice,
            projectedDays: projectedDays,
            settledCashBaseline: settledCashBaseline,
            accountValueNow: accountValueNow,
            grossNotional: grossNotional,
            marginReservedNow: marginReserved,
            maintenanceMargin50: maintenance50,
            availableToInvestNow: availableToInvestNow,
            marginLevelRatio: marginLevelRatio,
            unrealisedPnL: unrealisedPnL,
            dailyOvernightBurn: dailyBurn,
            projectedAdditionalFees: projectedFeeAdd,
            activePositionsCount: active.count,
            totalBuyUnits: buyUnits,
            totalSellUnits: sellUnits,
            netSignedUnits: netSignedUnits,
            grossUnits: grossUnits,
            leverageWeightedUnits: effUnits,
            weightedBuyEntry: weightedBuy,
            weightedSellEntry: weightedSell,
            netBreakEvenPriceNow: netBreakEvenNow,
            netBreakEvenPriceAfterDays: netBreakEvenAfterDays,
            zeroAvailableMarginPriceNow: p100Now,
            firstMarginCallPriceNow: p80Now,
            secondMarginCallPriceNow: p60Now,
            firstLiquidationPriceNow: p50Now,
            finalCascadeLiquidationPriceNow: finalCascadeNow,
            zeroEquityWipeoutPriceNow: p0Now,
            firstMarginCallPriceAfterDays: p80After,
            secondMarginCallPriceAfterDays: p60After,
            firstLiquidationPriceAfterDays: p50After,
            finalCascadeLiquidationPriceAfterDays: finalCascadeAfter,
            zeroEquityWipeoutPriceAfterDays: p0After,
            priceDropToFirstStopOut: priceDrop,
            priceDropPercentToFirstStopOut: priceDropPct,
            cashBufferAboveStopOut: cashBuffer,
            dailyLiquidationPriceDrift: dailyDrift,
            maxSurvivalDaysAtFlatPrice: maxSurvivalDays,
            cascadeStages: cascade
        )
    }

    private static func simulateSequentialCascade(
        activePositions: [CFDPosition],
        livePrice: Double,
        accountValueNow: Double,
        projectedFeeAdd: Double,
        p80Now: Double,
        p80After: Double
    ) -> [CascadeStage] {
        guard !activePositions.isEmpty else { return [] }
        var stages: [CascadeStage] = []

        let totalUnits = activePositions.reduce(0.0) { $0 + ($1.side == .buy ? $1.units : -$1.units) }
        let drop80Pct = livePrice > 0 ? ((p80Now - livePrice) / livePrice) * 100.0 : 0.0

        stages.append(CascadeStage(
            stageIndex: 1,
            title: "80% Margin Call Alert",
            subtitle: "Revolut sends margin warning notification",
            closedPositionDescription: "All \(activePositions.count) positions remain open",
            triggerPriceNow: p80Now,
            triggerPriceAfterDays: p80After,
            dropFromLivePercent: drop80Pct,
            remainingUnitsAfter: totalUnits,
            isCritical: false
        ))

        var remainingNow = activePositions
        var currentAnchorPriceNow = livePrice
        var currentEquityNow = accountValueNow

        var remainingAfter = activePositions
        var currentAnchorPriceAfter = livePrice
        var currentEquityAfter = max(0, accountValueNow - projectedFeeAdd)

        var step = 1
        while !remainingNow.isEmpty {
            let qNetNow = remainingNow.reduce(0.0) { $0 + ($1.side == .buy ? $1.units : -$1.units) }
            let qEffNow = remainingNow.reduce(0.0) { $0 + ($1.leverage > 0 ? $1.units / $1.leverage : 0) }

            let triggerNow = solveThresholdPrice(
                alpha: 0.50,
                netUnits: qNetNow,
                effUnits: qEffNow,
                livePrice: currentAnchorPriceNow,
                currentEquity: currentEquityNow,
                additionalFee: 0
            )

            let qNetAfter = remainingAfter.reduce(0.0) { $0 + ($1.side == .buy ? $1.units : -$1.units) }
            let qEffAfter = remainingAfter.reduce(0.0) { $0 + ($1.leverage > 0 ? $1.units / $1.leverage : 0) }
            let triggerAfter = solveThresholdPrice(
                alpha: 0.50,
                netUnits: qNetAfter,
                effUnits: qEffAfter,
                livePrice: currentAnchorPriceAfter,
                currentEquity: currentEquityAfter,
                additionalFee: 0
            )

            currentEquityNow += qNetNow * (triggerNow - currentAnchorPriceNow)
            currentAnchorPriceNow = triggerNow

            currentEquityAfter += qNetAfter * (triggerAfter - currentAnchorPriceAfter)
            currentAnchorPriceAfter = triggerAfter

            guard let worstIndex = remainingNow.indices.min(by: {
                remainingNow[$0].grossPnL(at: triggerNow) < remainingNow[$1].grossPnL(at: triggerNow)
            }) else { break }

            let closedPos = remainingNow.remove(at: worstIndex)
            if worstIndex < remainingAfter.count {
                remainingAfter.remove(at: worstIndex)
            }

            let remUnits = remainingNow.reduce(0.0) { $0 + ($1.side == .buy ? $1.units : -$1.units) }
            let isLast = remainingNow.isEmpty
            let dropPct = livePrice > 0 ? ((triggerNow - livePrice) / livePrice) * 100.0 : 0.0

            stages.append(CascadeStage(
                stageIndex: step + 1,
                title: isLast ? "Final Liquidation (All Closed)" : "Stop-Out Leg #\(step) (50%)",
                subtitle: isLast
                    ? "Last open position is force-closed at 50% Maintenance Margin"
                    : "Revolut closes largest losing position first",
                closedPositionDescription: "Closes \(closedPos.side.rawValue) \(String(format: "%.2f", closedPos.units)) @ $\(String(format: "%.2f", closedPos.entryPrice))",
                triggerPriceNow: triggerNow,
                triggerPriceAfterDays: triggerAfter,
                dropFromLivePercent: dropPct,
                remainingUnitsAfter: remUnits,
                isCritical: true
            ))

            step += 1
            if step > 8 { break }
        }

        return stages
    }

    // MARK: - Chart 1 Builder: Gold Price Milestones Bar Chart (Current vs Simulated)
    public static func buildMilestoneBars(
        base: PortfolioAnalytics,
        simulated: PortfolioAnalytics?,
        includeSimulation: Bool
    ) -> [PriceMilestoneBar] {
        var bars: [PriceMilestoneBar] = [
            PriceMilestoneBar(label: "Avg Entry", shortLabel: "Avg Entry", scenario: "Current", goldPrice: base.weightedBuyEntry, category: "Entry"),
            PriceMilestoneBar(label: "Live Gold", shortLabel: "Live Price", scenario: "Current", goldPrice: base.livePrice, category: "Live"),
            PriceMilestoneBar(label: "100% Margin", shortLabel: "Free=$0", scenario: "Current", goldPrice: base.zeroAvailableMarginPriceNow, category: "Warning"),
            PriceMilestoneBar(label: "80% Call", shortLabel: "80% Call", scenario: "Current", goldPrice: base.firstMarginCallPriceNow, category: "Warning"),
            PriceMilestoneBar(label: "1st Stop-Out", shortLabel: "1st Liq", scenario: "Current", goldPrice: base.firstLiquidationPriceNow, category: "Danger"),
            PriceMilestoneBar(label: "Final Stop-Out", shortLabel: "Final Liq", scenario: "Current", goldPrice: base.finalCascadeLiquidationPriceNow, category: "Danger")
        ]

        if includeSimulation, let sim = simulated {
            bars.append(contentsOf: [
                PriceMilestoneBar(label: "Avg Entry", shortLabel: "Avg Entry", scenario: "Simulated", goldPrice: sim.weightedBuyEntry, category: "Entry"),
                PriceMilestoneBar(label: "Live Gold", shortLabel: "Live Price", scenario: "Simulated", goldPrice: sim.livePrice, category: "Live"),
                PriceMilestoneBar(label: "100% Margin", shortLabel: "Free=$0", scenario: "Simulated", goldPrice: sim.zeroAvailableMarginPriceNow, category: "Warning"),
                PriceMilestoneBar(label: "80% Call", shortLabel: "80% Call", scenario: "Simulated", goldPrice: sim.firstMarginCallPriceNow, category: "Warning"),
                PriceMilestoneBar(label: "1st Stop-Out", shortLabel: "1st Liq", scenario: "Simulated", goldPrice: sim.firstLiquidationPriceNow, category: "Danger"),
                PriceMilestoneBar(label: "Final Stop-Out", shortLabel: "Final Liq", scenario: "Simulated", goldPrice: sim.finalCascadeLiquidationPriceNow, category: "Danger")
            ])
        }
        return bars
    }

    // MARK: - Chart 2 Builder: Discrete Horizon Overnight Creep Bar Chart
    public static func buildOvernightCreepBars(analytics: PortfolioAnalytics) -> [OvernightCreepBar] {
        let horizons = [0, 7, 14, 30, 60, 90, 180, 365]
        return horizons.map { d in
            let feeAdd = analytics.dailyOvernightBurn * Double(d)
            let p50 = solveThresholdPrice(
                alpha: 0.50,
                netUnits: analytics.netSignedUnits,
                effUnits: analytics.leverageWeightedUnits,
                livePrice: analytics.livePrice,
                currentEquity: analytics.accountValueNow,
                additionalFee: feeAdd
            )
            let creep = max(0, p50 - analytics.firstLiquidationPriceNow)
            return OvernightCreepBar(
                day: d,
                label: d == 0 ? "Now" : "\(d)d",
                stopOutGoldPrice: p50,
                finalCascadeGoldPrice: analytics.finalCascadeLiquidationPriceNow + creep,
                priceCreepDollars: creep,
                cumulativeSwapFee: feeAdd
            )
        }
    }

    // MARK: - Chart 3 Builder: What-If Additional Position Size Comparison Bars
    public static func buildSizeComparisonBars(
        positions: [CFDPosition],
        focusTicker: String,
        livePrice: Double,
        settledCashBaseline: Double,
        projectedDays: Int,
        simEntryPrice: Double,
        simSide: TradeSide
    ) -> [SizeSimulationBar] {
        let increments: [Double] = [0.0, 0.5, 1.0, 1.5, 2.0]
        var result: [SizeSimulationBar] = []

        for addU in increments {
            let cfg = SimulatedTradeConfig(
                isEnabled: addU > 0,
                side: simSide,
                units: addU,
                entryPrice: simEntryPrice,
                useLivePriceAsEntry: false
            )
            let eval = evaluate(
                positions: positions,
                focusTicker: focusTicker,
                livePrice: livePrice,
                settledCashBaseline: settledCashBaseline,
                projectedDays: projectedDays,
                simulatedTrade: cfg
            )
            let label = addU == 0 ? "Now" : "+\(String(format: "%.1f", addU)) oz"
            result.append(SizeSimulationBar(
                addedUnits: addU,
                addedUnitsLabel: label,
                metric: "Break-Even Gold Price",
                goldPrice: eval.weightedBuyEntry
            ))
            result.append(SizeSimulationBar(
                addedUnits: addU,
                addedUnitsLabel: label,
                metric: "50% Liquidation Gold Price",
                goldPrice: eval.firstLiquidationPriceNow
            ))
        }
        return result
    }
}
