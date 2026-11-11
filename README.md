<div align="center">

<img src="MarginGuard/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="MarginGuard App Icon" width="96" height="96" style="border-radius: 22px;" />

# MarginGuard

**Real-time Revolut CFD risk & liquidation guard for iOS**

Track exact commodity stop-out prices, sequential liquidation cascade ladders, and overnight swap decay — backed by live market rates, interactive What-If simulation, Home/Lock Screen widgets, and Dynamic Island Live Activities.

[![Platform](https://img.shields.io/badge/iOS-17.0%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid%20Glass-0A84FF?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-Supported-34C759?style=flat-square)](https://github.com/yonaskolb/XcodeGen)

</div>

---

## Overview

Most brokerage apps report margin risk as a single percentage (e.g. `1122%` or `80%`), leaving traders guessing what actual **market price** triggers a margin call or forced liquidation.

**MarginGuard** translates your open CFD positions and settled cash baseline directly into **exact instrument prices** (such as `$/oz` for Gold), showing you:

- Exactly where your **Free Margin hits `$0`** (`100%` margin level)
- The exact price triggers for **1st Margin Call (`80%`)**, **2nd Margin Call (`60%`)**, **Force Liquidation (`50%`)**, and **Zero Equity Wipeout (`$0`)**
- How **overnight financing fees** silently push your liquidation price closer every single day
- Which individual leg gets closed first — and at what price — in a **multi-position liquidation cascade**

---

## Key Features

### 1. Exact Liquidation & Margin Call Engine ([`CFDEngine`](Shared/CFDEngine.swift))
- **Dynamic Threshold Solver**: Computes exact instrument prices where $\text{Equity}(P) - \text{Fees} = \alpha \cdot \text{MarginReserved}(P)$ across all margin levels (`100%`, `80%`, `60%`, `50%`, and `0%`).
- **Sequential Liquidation Cascade Ladder**: Evaluates multi-leg portfolios step-by-step to reveal the exact trigger price and drop percentage for each successive stop-out stage.
- **Overnight Swap Decay**: Models daily financing burn and projects stop-out price drift over your chosen holding horizon (e.g. 30 days), including max survival days at a flat market price.

### 2. Live Market Rates & Instrument Presets ([`MarketPriceService`](MarginGuard/MarketPriceService.swift))
- **Concurrent 5-Second Auto-Refresh**: Polls live prices while active using Swift actors and task groups, with automatic foreground refresh on app activation.
- **Multi-Source Gold Fallback**: Queries Yahoo Finance (`GC=F`) with automatic fallbacks to Swissquote (`XAU/USD`) and Coinbase (`PAXG-USD`) spot feeds.
- **Built-In Presets**:

| Ticker | Instrument | Feed Symbol | Default Leverage | Default Annual Fee |
| :--- | :--- | :--- | :---: | :---: |
| `XAU/USD` | Gold Spot CFD | `GC=F` *(+ spot fallbacks)* | `20x` | `7.5%` |
| `XAG/USD` | Silver Spot CFD | `SI=F` | `10x` | `7.2%` |
| `WTI` | Crude Oil CFD | `CL=F` | `10x` | `6.8%` |
| `US100` | Nasdaq 100 CFD | `NQ=F` | `20x` | `7.5%` |
| `EUR/USD` | Euro / US Dollar | `EURUSD=X` | `30x` | `5.5%` |

### 3. Interactive What-If Simulation & Visual Charts ([`ChartsAnalyticsView`](MarginGuard/ChartsAnalyticsView.swift))
- **What-If Trade Overlay**: Toggle a simulated `BUY` or `SELL` trade (`0.25`–`5.0` units) to compare your current vs. simulated average entry and stop-out prices side-by-side.
- **Swift Charts Bar Diagrams**:
  - **Price Milestone Structure**: Average entry vs. live price vs. margin call and stop-out levels.
  - **Overnight Fee Creep**: Zoomed view showing how cumulative overnight fees shift your liquidation threshold over time.
  - **Position Size Stress Test**: Compares `+0.5` to `+2.0` unit additions against entry price and 1st stop-out impact.

### 4. Crash Survival Calculator & Smart Alerts ([`AlertsAndSettingsView`](MarginGuard/AlertsAndSettingsView.swift))
- **Cash Top-Up Calculator**: Slide to any target crash price to calculate the exact cash deposit needed today to keep your positions open over your holding horizon.
- **Local Risk Notifications** ([`NotificationManager`](MarginGuard/NotificationManager.swift)): Configurable alerts for margin call percentage thresholds, dollar distance to liquidation, and custom price floors.

### 5. Widgets & Dynamic Island Live Activities ([`MarginGuardWidgetBundle`](MarginGuardWidget/MarginGuardWidgetBundle.swift))
- **Home Screen & Lock Screen Widgets**: Displays live price, 1st stop-out price, drop cushion, average entry, and unrealized P&L via `WidgetKit`.
- **Live Activities & Dynamic Island**: Real-time lock screen and Dynamic Island tracking powered by `ActivityKit` and synced through a shared App Group container.

---

## App Structure

The app is organized into a 4-step setup wizard and a 3-tab Liquid Glass interface:

| Screen | Purpose |
| :--- | :--- |
| **Onboarding Wizard** | Select focus instrument, enter/edit open CFD legs, sync Revolut balance (`Account Value`, `Available to Invest`, or `Settled Cash`), and configure initial alert preferences. |
| **Guard** (`DashboardView`) | Live spot price hero card, stop-out cushion, What-If trade toggle, interactive price/days sliders, account metrics grid, liquidation cascade ladder, and active positions editor. |
| **Charts** (`ChartsAnalyticsView`) | Interactive Swift Charts comparing price milestones, overnight swap creep, and position sizing scenarios. |
| **Protection** (`AlertsAndSettingsView`) | What-If crash survival deposit calculator, smart notification triggers, test alert trigger, and Light / Dark / System appearance selector. |

---

## Project Architecture

```text
MarginGuard/
├── project.yml                        # XcodeGen specification (targets, settings, iOS 17.0)
├── MarginGuard.xcodeproj/             # Generated Xcode project
├── MarginGuard/                       # Main iOS application target
│   ├── MarginGuardApp.swift           # App entry point, scenePhase refresh & RootContainerView
│   ├── PortfolioStore.swift           # Observable state, App Group persistence & Live Activity sync
│   ├── MarketPriceService.swift       # Concurrent Yahoo/Swissquote/Coinbase live rate actor
│   ├── MarketDataService.swift        # Supporting market data helpers
│   ├── NotificationManager.swift      # UserNotifications risk threshold & test alerts
│   ├── OnboardingWizardView.swift     # 4-step setup & position/balance editor
│   ├── DashboardView.swift            # Guard tab with memoized subviews
│   ├── PositionAndBalanceSheets.swift # Modal sheets for editing legs & syncing balances
│   ├── ChartsAnalyticsView.swift      # Swift Charts diagrams & What-If comparisons
│   ├── AlertsAndSettingsView.swift    # Crash survival calculator, alerts & theme settings
│   ├── Info.plist                     # Live Activities & background fetch configuration
│   └── MarginGuard.entitlements       # App Group entitlement
├── MarginGuardWidget/                 # WidgetKit & ActivityKit extension target
│   ├── MarginGuardWidgetBundle.swift  # Home/Lock Screen widgets & Live Activity UI
│   ├── Info.plist
│   └── MarginGuardWidget.entitlements # Shared App Group entitlement
└── Shared/                            # Code compiled into both app & widget targets
    ├── CFDModels.swift                # Instruments, positions, number parser & theme modes
    ├── CFDEngine.swift                # Pure CFD math, liquidation cascade & chart builders
    ├── LiveActivityAttributes.swift   # ActivityKit attributes & shared widget snapshot schema
    └── LiquidGlassTheme.swift         # Adaptive Liquid Glass palette & styling primitives
```

---

## Getting Started

### Prerequisites

- **macOS** with **Xcode 16.0+** (Swift 5.10, iOS 17.0+ SDK)
- **iOS 17.0+** simulator or physical iPhone *(Dynamic Island requires iPhone 14 Pro or newer; Lock Screen Live Activities work on all iOS 17+ devices)*
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** *(optional — only needed if you modify `project.yml` and want to regenerate the `.xcodeproj`)*:
  ```bash
  brew install xcodegen
  ```

### 1. Clone the Repository

```bash
git clone https://github.com/usama242/MarginGuard.git
cd MarginGuard
```

### 2. Open (or Regenerate) the Xcode Project

You can open the existing project directly:

```bash
open MarginGuard.xcodeproj
```

Or regenerate it from [`project.yml`](project.yml) using XcodeGen:

```bash
xcodegen generate
open MarginGuard.xcodeproj
```

### 3. Configure Signing & App Groups *(Required for Physical Devices)*

Both the main app and widget extension share state via an App Group (`group.com.usama.marginguard.shared`). If you deploy to a physical iPhone with your own Apple Developer Team:

1. In Xcode, select the **MarginGuard** project and update the **Team** under **Signing & Capabilities** for both `MarginGuard` and `MarginGuardWidgetExtension`.
2. Change the bundle identifiers to a unique prefix (e.g., `com.<your-name>.marginguard.app` and `com.<your-name>.marginguard.app.widget`), or update `bundleIdPrefix` in [`project.yml`](project.yml) and run `xcodegen generate`.
3. Update the App Group identifier (`group.com.usama.marginguard.shared`) to match your developer account in:
   - [`MarginGuard/MarginGuard.entitlements`](MarginGuard/MarginGuard.entitlements)
   - [`MarginGuardWidget/MarginGuardWidget.entitlements`](MarginGuardWidget/MarginGuardWidget.entitlements)
   - [`MarginGuard/PortfolioStore.swift`](MarginGuard/PortfolioStore.swift) (`appGroupId`)
   - [`MarginGuardWidget/MarginGuardWidgetBundle.swift`](MarginGuardWidget/MarginGuardWidgetBundle.swift) (`appGroupId`)

> **Tip:** When running in the **iOS Simulator**, you can build and run immediately without an Apple Developer paid team or custom App Group provisioning.

### 4. Build & Run

1. Select the **MarginGuard** scheme and an iOS 17.0+ Simulator (or your connected iPhone).
2. Press **`⌘R`** to build and launch.
3. Complete the **4-step Onboarding Wizard** to enter your active CFD positions and sync your Revolut balance (`Account Value`, `Available to Invest`, or `Settled Cash`).

---

## Disclaimer

MarginGuard is an independent analytical and risk-visualization tool. It is **not affiliated with, endorsed by, or connected to Revolut**. Calculations are mathematical models based on user-supplied parameters and public market feeds, and do not constitute financial advice. Always verify margin requirements and open positions directly inside your brokerage platform.
