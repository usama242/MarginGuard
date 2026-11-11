import Foundation
import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()
    private init() {}

    public func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    public func evaluateAndScheduleSmartAlerts(analytics: PortfolioAnalytics, prefs: AlertPreferences) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard analytics.marginReservedNow > 0 else { return }
        let marginPct = analytics.marginLevelRatio * 100.0

        // 1. Margin Call Proximity / Threshold Alert
        if prefs.enableMarginCallAlerts && marginPct <= prefs.customMarginWarningPercent {
            scheduleImmediateNotification(
                id: "margin_call_warning",
                title: "⚠️ \(analytics.focusTicker) Margin Call Zone (\(String(format: "%.0f%%", marginPct)))",
                body: "\(analytics.focusTicker) is at $\(String(format: "%.2f", analytics.livePrice)). 80% Call triggers at $\(String(format: "%.2f", analytics.firstMarginCallPriceNow)), 1st Liquidation at $\(String(format: "%.2f", analytics.firstLiquidationPriceNow))."
            )
        }

        // 2. Gold Price Proximity to 50% Stop-Out Alert
        let distance = abs(analytics.livePrice - analytics.firstLiquidationPriceNow)
        if prefs.enableLiquidationProximity && distance <= prefs.liquidationBufferDollars {
            scheduleImmediateNotification(
                id: "liquidation_proximity",
                title: "🚨 \(analytics.focusTicker) Within $\(String(format: "%.0f", distance)) of Liquidation",
                body: "Live \(analytics.focusTicker): $\(String(format: "%.2f", analytics.livePrice)). 1st position liquidates at $\(String(format: "%.2f", analytics.firstLiquidationPriceNow))."
            )
        }

        // 3. Custom Commodity Price Floor Alert
        if prefs.enableCustomPriceAlert && analytics.livePrice <= prefs.targetPriceFloor {
            scheduleImmediateNotification(
                id: "custom_price_floor",
                title: "📉 \(analytics.focusTicker) Price Alert ($\(String(format: "%.2f", analytics.livePrice)))",
                body: "\(analytics.focusTicker) dropped below your $\(String(format: "%.2f", prefs.targetPriceFloor)) alert level. Liquidation is at $\(String(format: "%.2f", analytics.firstLiquidationPriceNow))."
            )
        }
    }

    public func sendSampleTestNotification(analytics: PortfolioAnalytics) {
        requestPermission { granted in
            guard granted else { return }
            self.scheduleImmediateNotification(
                id: "sample_test_alert",
                title: "🛡️ \(analytics.focusTicker) Guard: Live $\(String(format: "%.2f", analytics.livePrice))",
                body: "1st Liquidation Price: $\(String(format: "%.2f", analytics.firstLiquidationPriceNow)) (-$\(String(format: "%.0f", analytics.priceDropToFirstStopOut))/oz cushion) • Avg Entry: $\(String(format: "%.2f", analytics.weightedBuyEntry))."
            )
        }
    }

    private func scheduleImmediateNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.2, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
