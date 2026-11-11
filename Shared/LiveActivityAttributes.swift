import Foundation
#if canImport(ActivityKit)
import ActivityKit

// MARK: - ActivityKit Attributes Focused on Gold Price & Liquidation Gold Price
public struct CFDPositionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var livePrice: Double
        public var avgEntryPrice: Double
        public var accountValue: Double
        public var marginLevelPercent: Double
        public var stopOutPriceNow: Double
        public var finalStopOutPriceNow: Double
        public var priceBufferDollars: Double
        public var dailyOvernightBurn: Double
        public var unrealisedPnL: Double
        public var updatedAt: Date
    }

    public var ticker: String
    public var leverage: Int
}
#endif
