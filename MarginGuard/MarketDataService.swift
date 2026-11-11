import Foundation

/// Compatibility facade for callers that need market prices in batches.
/// The app's shared market data implementation lives in `MarketPriceService`.
public enum MarketDataService {
    public static func fetchPrices(for tickers: [String]) async -> [String: Double] {
        await MarketPriceService.shared.fetchPortfolioPrices(tickers: Set(tickers))
    }

    public static func fetchPrice(for ticker: String) async -> Double? {
        await MarketPriceService.shared.fetchLivePrice(for: ticker)
    }
}
