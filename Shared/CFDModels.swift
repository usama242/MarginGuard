import Foundation
import SwiftUI

// MARK: - Locale-Safe Decimal Parser (Supports both '.' and ',' separators)
public enum NumberParser {
    public static func parse(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }
}

// MARK: - App Appearance Mode
public enum AppThemeMode: String, CaseIterable, Codable, Identifiable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"
    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Revolut Balance Sync Mode
public enum BalanceInputMode: String, CaseIterable, Codable, Identifiable {
    case accountValue      = "Account Value"
    case availableToInvest = "Available to Invest"
    case cashBaseline      = "Settled Cash"
    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .accountValue:
            return "Enter 'Account value' from Revolut Balances (e.g. $3,435.40). Anchors your cash baseline at the current price."
        case .availableToInvest:
            return "Enter 'Available to Invest' from Revolut Balances (e.g. $3,129.10). Automatically derives Account Value."
        case .cashBaseline:
            return "Enter settled cash before open Unrealized P&L (Account Value minus Unrealized P&L, e.g. $4,141.45)."
        }
    }
}

// MARK: - Trade Direction
public enum TradeSide: String, CaseIterable, Codable, Identifiable {
    case buy  = "BUY"
    case sell = "SELL"
    public var id: String { rawValue }
}

// MARK: - Curated Instrument Presets (With Yahoo & Backup Spot Symbols)
public struct InstrumentPreset: Identifiable, Codable, Equatable {
    public var id: String { ticker }
    public let ticker: String
    public let yahooSymbol: String
    public let name: String
    public let symbolIcon: String
    public let defaultPrice: Double
    public let defaultLeverage: Double
    public let defaultAnnualFeeRate: Double
    public let unitLabel: String

    public static let presets: [InstrumentPreset] = [
        InstrumentPreset(
            ticker: "XAU/USD",
            yahooSymbol: "GC=F",
            name: "Gold Spot CFD",
            symbolIcon: "circle.hexagongrid.fill",
            defaultPrice: 4083.93,
            defaultLeverage: 20.0,
            defaultAnnualFeeRate: 0.075,
            unitLabel: "oz"
        ),
        InstrumentPreset(
            ticker: "XAG/USD",
            yahooSymbol: "SI=F",
            name: "Silver Spot CFD",
            symbolIcon: "sparkles",
            defaultPrice: 34.50,
            defaultLeverage: 10.0,
            defaultAnnualFeeRate: 0.072,
            unitLabel: "oz"
        ),
        InstrumentPreset(
            ticker: "WTI",
            yahooSymbol: "CL=F",
            name: "Crude Oil CFD",
            symbolIcon: "drop.fill",
            defaultPrice: 71.50,
            defaultLeverage: 10.0,
            defaultAnnualFeeRate: 0.068,
            unitLabel: "bbl"
        ),
        InstrumentPreset(
            ticker: "US100",
            yahooSymbol: "NQ=F",
            name: "Nasdaq 100 CFD",
            symbolIcon: "chart.line.uptrend.xyaxis",
            defaultPrice: 21450.00,
            defaultLeverage: 20.0,
            defaultAnnualFeeRate: 0.075,
            unitLabel: "units"
        ),
        InstrumentPreset(
            ticker: "EUR/USD",
            yahooSymbol: "EURUSD=X",
            name: "Euro / US Dollar",
            symbolIcon: "eurosign.circle.fill",
            defaultPrice: 1.085,
            defaultLeverage: 30.0,
            defaultAnnualFeeRate: 0.055,
            unitLabel: "lots"
        )
    ]

    /// Returns the configured instrument for a ticker, falling back to gold.
    public static func preset(for ticker: String) -> InstrumentPreset {
        presets.first(where: { $0.ticker == ticker }) ?? presets[0]
    }
}

// MARK: - Individual CFD Position Leg
public struct CFDPosition: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var ticker: String
    public var side: TradeSide
    public var units: Double
    public var entryPrice: Double
    public var leverage: Double
    public var annualOvernightRate: Double
    public var daysHeld: Int
    public var purchaseDate: Date?
    public var isActive: Bool = true

    public init(
        id: UUID = UUID(),
        ticker: String = "XAU/USD",
        side: TradeSide = .buy,
        units: Double = 0.5,
        entryPrice: Double = 4488.20,
        leverage: Double = 20.0,
        annualOvernightRate: Double = 0.075,
        daysHeld: Int = 0,
        purchaseDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.ticker = ticker
        self.side = side
        self.units = units
        self.entryPrice = entryPrice
        self.leverage = leverage
        self.annualOvernightRate = annualOvernightRate
        self.daysHeld = daysHeld
        self.purchaseDate = purchaseDate
        self.isActive = isActive
    }

    public func entryNotional() -> Double {
        units * entryPrice
    }

    public func currentNotional(at currentPrice: Double) -> Double {
        units * currentPrice
    }

    public func liveMarginReserved(at currentPrice: Double) -> Double {
        guard leverage > 0 else { return 0 }
        return currentNotional(at: currentPrice) / leverage
    }

    public func maintenanceMargin(at currentPrice: Double) -> Double {
        liveMarginReserved(at: currentPrice) * 0.50
    }

    /// Revolut Unrealized P&L (pure price P&L; past daily overnight fees are already settled in cash)
    public func grossPnL(at currentPrice: Double) -> Double {
        switch side {
        case .buy:  return units * (currentPrice - entryPrice)
        case .sell: return units * (entryPrice - currentPrice)
        }
    }

    public func dailyOvernightFee(at currentPrice: Double) -> Double {
        (currentNotional(at: currentPrice) * annualOvernightRate) / 365.0
    }
}

// MARK: - Non-Destructive "What-If" Simulated Trade Configuration
public struct SimulatedTradeConfig: Codable, Equatable {
    public var isEnabled: Bool = false
    public var side: TradeSide = .buy
    public var units: Double = 0.50
    public var entryPrice: Double = 4083.93
    public var useLivePriceAsEntry: Bool = true

    public init(
        isEnabled: Bool = false,
        side: TradeSide = .buy,
        units: Double = 0.50,
        entryPrice: Double = 4083.93,
        useLivePriceAsEntry: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.side = side
        self.units = units
        self.entryPrice = entryPrice
        self.useLivePriceAsEntry = useLivePriceAsEntry
    }
}

// MARK: - Notification Alert Configuration
public struct AlertPreferences: Codable, Equatable {
    public var enableMarginCallAlerts: Bool = true
    public var customMarginWarningPercent: Double = 85.0
    public var enableLiquidationProximity: Bool = true
    public var liquidationBufferDollars: Double = 250.0
    public var enableCustomPriceAlert: Bool = true
    public var targetPriceFloor: Double = 3950.0
    public var enableWeekendSwapReminder: Bool = true
}

// MARK: - Lightweight Shared Snapshot for Widget & Live Activity
public struct WidgetPortfolioSnapshot: Codable {
    public var focusTicker: String
    public var livePrice: Double
    public var averageEntryPrice: Double
    public var accountValue: Double
    public var marginReserved: Double
    public var maintenanceMargin: Double
    public var availableToInvest: Double
    public var marginLevelPercent: Double
    public var firstLiquidationPriceNow: Double
    public var finalCascadeLiquidationPriceNow: Double
    public var liquidationPriceAfterDays: Double
    public var priceDropToStopOut: Double
    public var projectedHorizonDays: Int
    public var dailyOvernightBurn: Double
    public var unrealisedPnL: Double
    public var statusLabel: String
    public var updatedAt: Date
}
