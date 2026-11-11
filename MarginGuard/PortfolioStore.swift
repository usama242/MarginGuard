import Foundation
import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
public final class PortfolioStore: ObservableObject {
    public static let appGroupId = "group.com.usama.marginguard.shared"

    // MARK: - Published User State
    @Published public var hasCompletedOnboarding: Bool { didSet { scheduleSave() } }
    @Published public var themeMode: AppThemeMode          { didSet { scheduleSave() } }
    @Published public var focusTicker: String              { didSet { scheduleSave(); recomputeAnalytics() } }
    @Published public var balanceMode: BalanceInputMode    { didSet { scheduleSave() } }
    @Published public var balanceInputAmount: Double       { didSet { scheduleSave() } }

    /// Settled Cash Baseline — stays constant as live price fluctuates so Account Value updates dynamically.
    @Published public var settledCashBaseline: Double {
        didSet { scheduleSave(); recomputeAnalytics() }
    }
    @Published public var projectedHoldingDays: Int {
        didSet { scheduleSave(); recomputeAnalytics() }
    }
    @Published public var positions: [CFDPosition] {
        didSet { scheduleSave(); recomputeAnalytics() }
    }
    @Published public var simulatedTrade: SimulatedTradeConfig {
        didSet { scheduleSave(); recomputeAnalytics() }
    }
    @Published public var alertPrefs: AlertPreferences { didSet { scheduleSave() } }

    // MARK: - Live Refresh State (not persisted on every tick)
    @Published public var autoRefreshEnabled: Bool = true
    @Published public var isFetchingPrice: Bool = false
    @Published public var lastPriceUpdate: Date = Date()
    @Published public var isLiveActivityRunning: Bool = false

    /// Single source of truth for the current live price of the focus ticker.
    @Published public var liveMarketPrice: Double {
        didSet { recomputeAnalytics() }
    }

    // MARK: - Cached Analytics (Updated only when data changes, not on every render)
    @Published public private(set) var analytics: PortfolioAnalytics = PortfolioAnalytics.empty
    @Published public private(set) var simulatedAnalytics: PortfolioAnalytics = PortfolioAnalytics.empty
    @Published public private(set) var activeAnalytics: PortfolioAnalytics = PortfolioAnalytics.empty

    // All live prices, keyed by ticker (focus ticker is also mirrored here)
    private var livePricesByTicker: [String: Double] = [:]

    private var refreshTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var computeTask: Task<Void, Never>?

    // MARK: - Convenience
    public var selectedPreset: InstrumentPreset {
        InstrumentPreset.presets.first(where: { $0.ticker == focusTicker }) ?? InstrumentPreset.presets[0]
    }

    public var marketPrices: [String: Double] {
        var prices = livePricesByTicker
        prices[focusTicker] = liveMarketPrice
        return prices
    }

    // MARK: - Init
    public init() {
        let defaults = UserDefaults(suiteName: Self.appGroupId) ?? .standard

        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        if let rawTheme = defaults.string(forKey: "themeMode"),
           let mode = AppThemeMode(rawValue: rawTheme) {
            self.themeMode = mode
        } else {
            self.themeMode = .system
        }

        self.focusTicker = defaults.string(forKey: "focusTicker") ?? "XAU/USD"
        let savedPrice = defaults.double(forKey: "liveMarketPrice")
        self.liveMarketPrice = savedPrice > 0 ? savedPrice : 4083.93

        if let rawBalMode = defaults.string(forKey: "balanceMode"),
           let bMode = BalanceInputMode(rawValue: rawBalMode) {
            self.balanceMode = bMode
        } else {
            self.balanceMode = .accountValue
        }

        let savedBal = defaults.double(forKey: "balanceInputAmount")
        self.balanceInputAmount = savedBal > 0 ? savedBal : 3435.40

        let savedDays = defaults.integer(forKey: "projectedHoldingDays")
        self.projectedHoldingDays = savedDays > 0 ? savedDays : 30

        let defaultPositions: [CFDPosition] = [
            CFDPosition(ticker: "XAU/USD", side: .buy, units: 0.50, entryPrice: 4488.20,
                        leverage: 20.0, annualOvernightRate: 0.075, daysHeld: 0, isActive: true),
            CFDPosition(ticker: "XAU/USD", side: .buy, units: 0.50, entryPrice: 4554.98,
                        leverage: 20.0, annualOvernightRate: 0.075, daysHeld: 0, isActive: true),
            CFDPosition(ticker: "XAU/USD", side: .buy, units: 0.50, entryPrice: 4620.00,
                        leverage: 20.0, annualOvernightRate: 0.075, daysHeld: 0, isActive: true)
        ]

        if let posData = defaults.data(forKey: "positions"),
           let decoded = try? JSONDecoder().decode([CFDPosition].self, from: posData),
           !decoded.isEmpty {
            self.positions = decoded.map { p in
                var updated = p
                if abs(updated.entryPrice - 4555.0) < 0.05 && abs(updated.units - 0.5) < 0.01 {
                    updated.entryPrice = 4554.98
                }
                if abs(updated.entryPrice - 4488.0) < 0.05 && abs(updated.units - 0.5) < 0.01 {
                    updated.entryPrice = 4488.20
                }
                return updated
            }
        } else {
            self.positions = defaultPositions
        }

        let savedSettled = defaults.double(forKey: "settledCashBaseline")
        self.settledCashBaseline = savedSettled > 0 ? savedSettled : 4141.47

        if let simData = defaults.data(forKey: "simulatedTrade"),
           let decodedSim = try? JSONDecoder().decode(SimulatedTradeConfig.self, from: simData) {
            self.simulatedTrade = decodedSim
        } else {
            self.simulatedTrade = SimulatedTradeConfig(
                isEnabled: false, side: .buy, units: 0.50,
                entryPrice: 4083.93, useLivePriceAsEntry: true
            )
        }

        if let alertData = defaults.data(forKey: "alertPrefs"),
           let decodedAlerts = try? JSONDecoder().decode(AlertPreferences.self, from: alertData) {
            self.alertPrefs = decodedAlerts
        } else {
            self.alertPrefs = AlertPreferences()
        }

        // Seed the initial cached analytics immediately for instant launch rendering
        let initialBase = CFDEngine.evaluate(
            positions: self.positions,
            focusTicker: self.focusTicker,
            livePrice: self.liveMarketPrice,
            settledCashBaseline: self.settledCashBaseline,
            projectedDays: self.projectedHoldingDays,
            simulatedTrade: nil
        )
        let initialSim = CFDEngine.evaluate(
            positions: self.positions,
            focusTicker: self.focusTicker,
            livePrice: self.liveMarketPrice,
            settledCashBaseline: self.settledCashBaseline,
            projectedDays: self.projectedHoldingDays,
            simulatedTrade: self.simulatedTrade
        )
        self.analytics = initialBase
        self.simulatedAnalytics = initialSim
        self.activeAnalytics = self.simulatedTrade.isEnabled ? initialSim : initialBase

        startTimers()
        syncWidgetAndLiveActivity(forceLiveActivityUpdate: true)

        Task {
            await refreshMarketPricesNow()
        }
    }

    // MARK: - Parallel Asynchronous Analytics Recompute (Off Main Thread)
    private func recomputeAnalytics() {
        computeTask?.cancel()

        let pos = positions
        let ticker = focusTicker
        let price = liveMarketPrice
        let settled = settledCashBaseline
        let days = projectedHoldingDays
        let sim = simulatedTrade

        // Dispatches to PortfolioComputeActor across multi-core background threads.
        // Leaves Main Thread 100% responsive for 120Hz ProMotion scrolling.
        computeTask = Task(priority: .userInitiated) { [weak self] in
            let result = await PortfolioComputeActor.shared.compute(
                positions: pos,
                focusTicker: ticker,
                livePrice: price,
                settledCashBaseline: settled,
                projectedDays: days,
                simulatedTrade: sim
            )
            guard !Task.isCancelled else { return }
            self?.applyAnalytics(base: result.base, sim: result.sim, active: result.active)
        }
    }

    @MainActor
    private func applyAnalytics(base: PortfolioAnalytics, sim: PortfolioAnalytics, active: PortfolioAnalytics) {
        if self.analytics != base {
            self.analytics = base
        }
        if self.simulatedAnalytics != sim {
            self.simulatedAnalytics = sim
        }
        if self.activeAnalytics != active {
            self.activeAnalytics = active
        }
    }

    // MARK: - Revolut Balance Anchor Calculation
    public func syncRevolutBalance(mode: BalanceInputMode, amount: Double, atPrice referencePrice: Double? = nil) {
        let price = referencePrice ?? liveMarketPrice
        let active = positions.filter { $0.isActive && $0.units > 0 }
        let currentGrossPnL = active.reduce(0.0) { $0 + $1.grossPnL(at: price) }
        let currentMarginReserved = active.reduce(0.0) { $0 + $1.liveMarginReserved(at: price) }

        self.balanceMode = mode
        self.balanceInputAmount = amount

        switch mode {
        case .accountValue:
            self.settledCashBaseline = amount - currentGrossPnL
        case .availableToInvest:
            self.settledCashBaseline = amount + currentMarginReserved - currentGrossPnL
        case .cashBaseline:
            self.settledCashBaseline = amount
        }
    }

    public func syncRevolutBalance(mode: BalanceInputMode, amount: Double, atReferencePrices referencePrices: [String: Double]) {
        let active = positions.filter { $0.isActive && $0.units > 0 }
        let currentGrossPnL = active.reduce(0.0) { total, position in
            total + position.grossPnL(at: referencePrices[position.ticker] ?? livePricesByTicker[position.ticker] ?? liveMarketPrice)
        }
        let currentMarginReserved = active.reduce(0.0) { total, position in
            total + position.liveMarginReserved(at: referencePrices[position.ticker] ?? livePricesByTicker[position.ticker] ?? liveMarketPrice)
        }

        balanceMode = mode
        balanceInputAmount = amount
        switch mode {
        case .accountValue:
            settledCashBaseline = amount - currentGrossPnL
        case .availableToInvest:
            settledCashBaseline = amount + currentMarginReserved - currentGrossPnL
        case .cashBaseline:
            settledCashBaseline = amount
        }
    }

    // MARK: - Timers: 5-Second App Price Refresh & 1-Minute Live Activity Push
    public func startTimers() {
        refreshTask?.cancel()

        // Single background async loop — does NOT block the main RunLoop during scroll.
        // The 5s sleep happens off-thread; only the actual property assignment touches @MainActor.
        refreshTask = Task { [weak self] in
            var tickCount: Int = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds, off main thread
                guard let self = self, !Task.isCancelled else { break }
                guard self.autoRefreshEnabled else { continue }
                tickCount += 1
                await self.refreshMarketPricesNow(isBackgroundTick: true)
                // Every 12th tick (60s): push Live Activity / widget update
                if tickCount % 12 == 0 {
                    self.syncWidgetAndLiveActivity(forceLiveActivityUpdate: true)
                }
            }
        }
    }

    // MARK: - Live Market Rate Fetch (Manual Button + 5s Auto Timer)
    public func refreshMarketPricesNow(isBackgroundTick: Bool = false) async {
        if !isBackgroundTick {
            isFetchingPrice = true
        }
        var tickersToFetch: Set<String> = [focusTicker]
        for pos in positions where pos.isActive {
            tickersToFetch.insert(pos.ticker)
        }

        let fetched = await MarketPriceService.shared.fetchPortfolioPrices(tickers: tickersToFetch)
        if !fetched.isEmpty {
            // Batch all price assignments into a single published update
            var updatedPrices = livePricesByTicker
            var priceChanged = false

            for (tk, price) in fetched {
                if abs((updatedPrices[tk] ?? 0) - price) >= 0.005 {
                    updatedPrices[tk] = price
                    priceChanged = true
                }
            }

            if priceChanged {
                livePricesByTicker = updatedPrices
            }

            if let focusLive = fetched[focusTicker], focusLive > 0 {
                if abs(liveMarketPrice - focusLive) >= 0.005 {
                    liveMarketPrice = focusLive   // triggers recomputeAnalytics() once via didSet
                }
                // Update simulated entry only if it uses live price (don't trigger saveState for every tick)
                if simulatedTrade.useLivePriceAsEntry, abs(simulatedTrade.entryPrice - focusLive) >= 0.005 {
                    // Assign directly without full didSet cascade — just update the entry price field
                    simulatedTrade = SimulatedTradeConfig(
                        isEnabled: simulatedTrade.isEnabled,
                        side: simulatedTrade.side,
                        units: simulatedTrade.units,
                        entryPrice: focusLive,
                        useLivePriceAsEntry: true
                    )
                }
            }

            // Only publish lastPriceUpdate once per minute to avoid flooding the header
            if Calendar.current.component(.minute, from: lastPriceUpdate) !=
               Calendar.current.component(.minute, from: Date()) {
                lastPriceUpdate = Date()
            }
        } else if !isBackgroundTick,
                  Calendar.current.component(.minute, from: lastPriceUpdate) !=
                  Calendar.current.component(.minute, from: Date()) {
            lastPriceUpdate = Date()
        }

        if !isBackgroundTick {
            isFetchingPrice = false
            syncWidgetAndLiveActivity(forceLiveActivityUpdate: true)
        }
    }

    // MARK: - Debounced Persistence (keeps main thread free during rapid slider drags / ticks)
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            guard let self = self, !Task.isCancelled else { return }
            self.saveState()
        }
    }

    // MARK: - Persistence & AppGroup Widget Sync
    public func saveState() {
        let defaults = UserDefaults(suiteName: Self.appGroupId) ?? .standard
        defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        defaults.set(themeMode.rawValue, forKey: "themeMode")
        defaults.set(focusTicker, forKey: "focusTicker")
        defaults.set(liveMarketPrice, forKey: "liveMarketPrice")
        defaults.set(balanceMode.rawValue, forKey: "balanceMode")
        defaults.set(balanceInputAmount, forKey: "balanceInputAmount")
        defaults.set(settledCashBaseline, forKey: "settledCashBaseline")
        defaults.set(projectedHoldingDays, forKey: "projectedHoldingDays")

        if let posData = try? JSONEncoder().encode(positions) {
            defaults.set(posData, forKey: "positions")
        }
        if let simData = try? JSONEncoder().encode(simulatedTrade) {
            defaults.set(simData, forKey: "simulatedTrade")
        }
        if let alertData = try? JSONEncoder().encode(alertPrefs) {
            defaults.set(alertData, forKey: "alertPrefs")
        }

        syncWidgetAndLiveActivity(forceLiveActivityUpdate: false)
        NotificationManager.shared.evaluateAndScheduleSmartAlerts(analytics: analytics, prefs: alertPrefs)
    }

    public func syncWidgetAndLiveActivity(forceLiveActivityUpdate: Bool) {
        let defaults = UserDefaults(suiteName: Self.appGroupId) ?? .standard
        let current = analytics
        let snapshot = WidgetPortfolioSnapshot(
            focusTicker: current.focusTicker,
            livePrice: current.livePrice,
            averageEntryPrice: current.weightedBuyEntry,
            accountValue: current.accountValueNow,
            marginReserved: current.marginReservedNow,
            maintenanceMargin: current.maintenanceMargin50,
            availableToInvest: current.availableToInvestNow,
            marginLevelPercent: current.marginLevelRatio * 100.0,
            firstLiquidationPriceNow: current.firstLiquidationPriceNow,
            finalCascadeLiquidationPriceNow: current.finalCascadeLiquidationPriceNow,
            liquidationPriceAfterDays: current.firstLiquidationPriceAfterDays,
            priceDropToStopOut: current.priceDropToFirstStopOut,
            projectedHorizonDays: current.projectedDays,
            dailyOvernightBurn: current.dailyOvernightBurn,
            unrealisedPnL: current.unrealisedPnL,
            statusLabel: current.statusText,
            updatedAt: Date()
        )
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: "widgetSnapshot")
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        if forceLiveActivityUpdate {
            updateLiveActivityIfActive()
        }
    }

    // MARK: - Live Activity Control (Dynamic Island + Lock Screen)
    public func toggleLiveActivity() {
        #if canImport(ActivityKit)
        if isLiveActivityRunning {
            stopLiveActivity()
        } else {
            startLiveActivity()
        }
        #endif
    }

    public func startLiveActivity() {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let current = analytics
        let attributes = CFDPositionAttributes(
            ticker: current.focusTicker,
            leverage: Int(selectedPreset.defaultLeverage)
        )
        let state = CFDPositionAttributes.ContentState(
            livePrice: current.livePrice,
            avgEntryPrice: current.weightedBuyEntry,
            accountValue: current.accountValueNow,
            marginLevelPercent: current.marginLevelRatio * 100.0,
            stopOutPriceNow: current.firstLiquidationPriceNow,
            finalStopOutPriceNow: current.finalCascadeLiquidationPriceNow,
            priceBufferDollars: current.priceDropToFirstStopOut,
            dailyOvernightBurn: current.dailyOvernightBurn,
            unrealisedPnL: current.unrealisedPnL,
            updatedAt: Date()
        )
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Calendar.current.date(byAdding: .minute, value: 2, to: Date())),
                pushType: nil
            )
            isLiveActivityRunning = true
        } catch {
            isLiveActivityRunning = false
        }
        #endif
    }

    public func updateLiveActivityIfActive() {
        #if canImport(ActivityKit)
        let current = analytics
        let state = CFDPositionAttributes.ContentState(
            livePrice: current.livePrice,
            avgEntryPrice: current.weightedBuyEntry,
            accountValue: current.accountValueNow,
            marginLevelPercent: current.marginLevelRatio * 100.0,
            stopOutPriceNow: current.firstLiquidationPriceNow,
            finalStopOutPriceNow: current.finalCascadeLiquidationPriceNow,
            priceBufferDollars: current.priceDropToFirstStopOut,
            dailyOvernightBurn: current.dailyOvernightBurn,
            unrealisedPnL: current.unrealisedPnL,
            updatedAt: Date()
        )
        Task {
            for activity in Activity<CFDPositionAttributes>.activities {
                await activity.update(
                    ActivityContent(
                        state: state,
                        staleDate: Calendar.current.date(byAdding: .minute, value: 2, to: Date())
                    )
                )
            }
        }
        #endif
    }

    public func stopLiveActivity() {
        #if canImport(ActivityKit)
        Task {
            for activity in Activity<CFDPositionAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            isLiveActivityRunning = false
        }
        #endif
    }
}

// MARK: - Multi-Core Parallel Computing Actor
/// Executes CFD evaluation pipelines concurrently on worker CPU cores.
/// Offloads all mathematical simulations from the main UI thread.
public actor PortfolioComputeActor {
    public static let shared = PortfolioComputeActor()
    private init() {}

    public func compute(
        positions: [CFDPosition],
        focusTicker: String,
        livePrice: Double,
        settledCashBaseline: Double,
        projectedDays: Int,
        simulatedTrade: SimulatedTradeConfig
    ) async -> (base: PortfolioAnalytics, sim: PortfolioAnalytics, active: PortfolioAnalytics) {
        // Parallel multi-core dispatch: evaluate base portfolio and virtual scenario concurrently
        async let baseTask = Task.detached(priority: .userInitiated) {
            CFDEngine.evaluate(
                positions: positions,
                focusTicker: focusTicker,
                livePrice: livePrice,
                settledCashBaseline: settledCashBaseline,
                projectedDays: projectedDays,
                simulatedTrade: nil
            )
        }.value

        async let simTask = Task.detached(priority: .userInitiated) {
            CFDEngine.evaluate(
                positions: positions,
                focusTicker: focusTicker,
                livePrice: livePrice,
                settledCashBaseline: settledCashBaseline,
                projectedDays: projectedDays,
                simulatedTrade: simulatedTrade
            )
        }.value

        let (base, sim) = await (baseTask, simTask)
        let active = simulatedTrade.isEnabled ? sim : base
        return (base, sim, active)
    }
}
