import Foundation

// MARK: - Live Commodity & CFD Market Rate Fetcher (Yahoo Finance + Spot Gold Fallbacks)
public actor MarketPriceService {
    public static let shared = MarketPriceService()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 5.0
        return URLSession(configuration: config)
    }()

    /// Fetches the latest market price for a given ticker (e.g., "XAU/USD")
    public func fetchLivePrice(for ticker: String) async -> Double? {
        if ticker == "XAU/USD" {
            // Try Yahoo Spot Gold / Futures or PAXG/Swissquote Spot XAU/USD
            if let p = await fetchYahooChartPrice(symbol: "GC=F") {
                return p
            }
            if let p = await fetchSwissquoteGoldSpot() {
                return p
            }
            if let p = await fetchCoinbasePaxGoldSpot() {
                return p
            }
            return nil
        }

        let symbolMap: [String: String] = [
            "XAG/USD": "SI=F",
            "WTI": "CL=F",
            "US100": "NQ=F",
            "EUR/USD": "EURUSD=X"
        ]
        let yahooSym = symbolMap[ticker] ?? ticker
        return await fetchYahooChartPrice(symbol: yahooSym)
    }

    /// Fetches all active tickers in the user's portfolio concurrently
    public func fetchPortfolioPrices(tickers: Set<String>) async -> [String: Double] {
        var results: [String: Double] = [:]
        await withTaskGroup(of: (String, Double?).self) { group in
            for t in tickers {
                group.addTask {
                    let price = await self.fetchLivePrice(for: t)
                    return (t, price)
                }
            }
            for await (ticker, price) in group {
                if let p = price, p > 0 {
                    results[ticker] = p
                }
            }
        }
        return results
    }

    private func fetchYahooChartPrice(symbol: String) async -> Double? {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1m&range=1d") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart = json["chart"] as? [String: Any],
               let resultArr = chart["result"] as? [[String: Any]],
               let first = resultArr.first,
               let meta = first["meta"] as? [String: Any],
               let price = meta["regularMarketPrice"] as? Double,
               price > 0 {
                return price
            }
        } catch {
            return nil
        }
        return nil
    }

    private func fetchSwissquoteGoldSpot() async -> Double? {
        guard let url = URL(string: "https://forex-data-feed.swissquote.com/public-quotes/bboquotes/instrument/XAU/USD") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = arr.first,
               let spreads = first["spreadProfilePrices"] as? [[String: Any]],
               let std = spreads.first,
               let bid = std["bid"] as? Double,
               let ask = std["ask"] as? Double,
               bid > 0, ask > 0 {
                return (bid + ask) / 2.0
            }
        } catch {
            return nil
        }
        return nil
    }

    private func fetchCoinbasePaxGoldSpot() async -> Double? {
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/PAXG-USD/spot") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let amountStr = dataObj["amount"] as? String,
               let val = Double(amountStr), val > 0 {
                return val
            }
        } catch {
            return nil
        }
        return nil
    }
}
