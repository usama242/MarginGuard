import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct MarginGuardWidgetBundle: WidgetBundle {
    var body: some Widget {
        MarginGuardHomeWidget()
        #if canImport(ActivityKit)
        CFDPositionLiveActivityWidget()
        #endif
    }
}

// MARK: - 1-Minute Granular Timeline Provider Reading Shared AppGroup Snapshot
struct MarginGuardProvider: TimelineProvider {
    let appGroupId = "group.com.usama.marginguard.shared"

    func placeholder(in context: Context) -> MarginGuardEntry {
        MarginGuardEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (MarginGuardEntry) -> Void) {
        completion(MarginGuardEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MarginGuardEntry>) -> Void) {
        let snap = loadSnapshot()
        var entries: [MarginGuardEntry] = []
        let now = Date()
        // Provide 1-minute timeline entries for the next 15 minutes
        for minuteOffset in 0..<15 {
            if let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) {
                entries.append(MarginGuardEntry(date: entryDate, snapshot: snap))
            }
        }
        let nextReload = Calendar.current.date(byAdding: .minute, value: 1, to: now)!
        completion(Timeline(entries: entries, policy: .after(nextReload)))
    }

    private func loadSnapshot() -> WidgetPortfolioSnapshot {
        let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
        if let data = defaults.data(forKey: "widgetSnapshot"),
           let decoded = try? JSONDecoder().decode(WidgetPortfolioSnapshot.self, from: data) {
            return decoded
        }
        return sampleSnapshot
    }

    private var sampleSnapshot: WidgetPortfolioSnapshot {
        WidgetPortfolioSnapshot(
            focusTicker: "XAU/USD",
            livePrice: 4083.93,
            averageEntryPrice: 4554.39,
            accountValue: 3435.40,
            marginReserved: 306.30,
            maintenanceMargin: 153.15,
            availableToInvest: 3129.10,
            marginLevelPercent: 1122.0,
            firstLiquidationPriceNow: 1839.65,
            finalCascadeLiquidationPriceNow: 1769.50,
            liquidationPriceAfterDays: 1865.10,
            priceDropToStopOut: 2244.28,
            projectedHorizonDays: 30,
            dailyOvernightBurn: 1.26,
            unrealisedPnL: -705.71,
            statusLabel: "HEALTHY (1122%)",
            updatedAt: Date()
        )
    }
}

struct MarginGuardEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPortfolioSnapshot
}

// MARK: - Gold-Price-Centric Home Screen & Lock Screen Widget View
struct MarginGuardWidgetEntryView: View {
    var entry: MarginGuardProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(s.focusTicker) $\(String(format: "%.2f", s.livePrice))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Spacer()
                    Text("Liq $\(String(format: "%.0f", s.firstLiquidationPriceNow))")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                Text("Drop Buffer: -$\(String(format: "%.0f", s.priceDropToStopOut))/oz")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("Avg Entry: $\(String(format: "%.2f", s.averageEntryPrice)) • P&L \(String(format: "%+.0f$", s.unrealisedPnL))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(s.focusTicker)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)
                    Spacer()
                    Text("$\(String(format: "%.0f", s.livePrice))")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassPalette.safeEmerald)
                }
                Spacer()
                Text("LIQUIDATES AT GOLD")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("$\(String(format: "%.2f", s.firstLiquidationPriceNow))")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassPalette.dangerCoral)
                Text("-$\(String(format: "%.0f", s.priceDropToStopOut))/oz cushion")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        default:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(s.focusTicker) LIVE • $\(String(format: "%.2f", s.livePrice))/oz")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.accentGold)

                    Text("1ST STOP-OUT GOLD PRICE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("$\(String(format: "%.2f", s.firstLiquidationPriceNow))")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassPalette.dangerCoral)

                    Text("All Closed @ $\(String(format: "%.2f", s.finalCascadeLiquidationPriceNow))/oz")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Avg $\(String(format: "%.2f", s.averageEntryPrice))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GlassPalette.safeEmerald)
                    Text("Cushion: -$\(String(format: "%.0f", s.priceDropToStopOut))/oz")
                        .font(.system(size: 11, weight: .semibold))
                    Text("P&L: \(String(format: "%+.2f$", s.unrealisedPnL))")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Equity: $\(String(format: "%.2f", s.accountValue))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
        }
    }
}

struct MarginGuardHomeWidget: Widget {
    let kind: String = "MarginGuardHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarginGuardProvider()) { entry in
            MarginGuardWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [GlassPalette.canvasTop, GlassPalette.canvasBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Gold Price Liquidation Guard")
        .description("Tracks live Gold price, 50% Stop-Out Gold price, and $/oz cushion.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

#if canImport(ActivityKit)
// MARK: - Live Activity & Dynamic Island Focused on Gold Price & Stop-Out Gold Price (1m Refresh)
struct CFDPositionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CFDPositionAttributes.self) { context in
            // Lock Screen Live Activity Banner
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(GlassPalette.accentGold)
                        Text("\(context.attributes.ticker) Live: $\(String(format: "%.2f", context.state.livePrice))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    Text("Liquidates @ $\(String(format: "%.2f", context.state.stopOutPriceNow))/oz")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(GlassPalette.dangerCoral)
                    Text("Avg Entry: $\(String(format: "%.2f", context.state.avgEntryPrice)) • Buffer: -$\(String(format: "%.0f", context.state.priceBufferDollars))/oz")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%+.1f$", context.state.unrealisedPnL))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(context.state.unrealisedPnL >= 0 ? GlassPalette.safeEmerald : GlassPalette.dangerCoral)
                    Text("Equity $\(String(format: "%.0f", context.state.accountValue))")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.78))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.attributes.ticker) LIVE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.accentGold)
                        Text("$\(String(format: "%.2f", context.state.livePrice))")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("1ST STOP-OUT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("$\(String(format: "%.2f", context.state.stopOutPriceNow))")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(GlassPalette.dangerCoral)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Avg Entry: $\(String(format: "%.2f", context.state.avgEntryPrice))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("Cushion: -$\(String(format: "%.0f", context.state.priceBufferDollars))/oz")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassPalette.safeEmerald)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Text("$\(String(format: "%.0f", context.state.livePrice))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)
            } compactTrailing: {
                Text("Liq $\(String(format: "%.0f", context.state.stopOutPriceNow))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.dangerCoral)
            } minimal: {
                Text("$\(String(format: "%.0f", context.state.livePrice))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassPalette.accentGold)
            }
        }
    }
}
#endif
