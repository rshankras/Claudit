# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Claudit** is a macOS 14+ menubar application that tracks Claude Code usage costs and quotas. It parses local JSONL session files and fetches real-time quota data from the Anthropic API to provide detailed cost analytics, cache efficiency metrics, and optimization recommendations.

> **Note:** This is an independent project, not affiliated with Anthropic.

## Build and Run Commands

### Build
```bash
xcodebuild -project Claudit.xcodeproj -scheme Claudit -configuration Debug build
```

### Run in Xcode
Open `Claudit.xcodeproj` in Xcode and press Cmd+R.

### Clean Build
```bash
xcodebuild -project Claudit.xcodeproj -scheme Claudit clean
```

### Build for Distribution
```bash
# Set environment variables first
export TEAM_ID="your-team-id"
export APPLE_ID="your@email.com"
export APP_PASSWORD="app-specific-password"

./scripts/notarize.sh
```

## Architecture Overview

### Core Design Pattern: Observable + SwiftData Hybrid

The app uses a **two-tier data architecture**:

1. **SwiftData Cache** (persistent, fast UI loading)
   - `DataManager` manages SwiftData persistence
   - `CachedDailyUsage`, `CachedProjectUsage`, `CachedSummary` models
   - Instant UI updates on launch (58ms typical)

2. **JSONL Parsing** (real-time, accurate)
   - `JSONLParser` (Swift actor) reads `~/.claude/projects/*/[session].jsonl`
   - Parses only today's files after initial bootstrap
   - Updates SwiftData cache in background

3. **Merge Strategy**
   - Fresh JSONL data overrides SwiftData for same-day entries
   - Historical data from SwiftData used when JSONL not available
   - `StatsManager.aggregatedUsage(since:)` combines both sources

### Data Flow

```
App Launch
    ↓
DataManager.loadFromSwiftData() → Instant UI (cached data)
    ↓
JSONLParser.dailyUsage(today) → Background parse (~1-2s)
JSONLParser.usageByProject(week/month/all) → Parse for 3 time ranges
    ↓
StatsManager.calculateCosts() → Merge JSONL + SwiftData
    ↓
DataManager.batchUpdateDailyUsage() → Update cache
    ↓
UI updates via @Observable
```

### Key Services

#### StatsManager (`Services/StatsManager.swift`)
- **Central data hub** decorated with `@Observable` and `@MainActor`
- Coordinates JSONL parsing, SwiftData loading, and API quota fetching
- Exposes computed properties for UI: costs, tokens, cache efficiency, quotas
- **Bootstrap logic**: First run parses full month, subsequent runs parse only today
- **Performance**: Uses `Task.detached` for background parsing to avoid blocking UI
- **Cleanup**: Call `cleanup()` before discarding to remove NotificationCenter observers

#### JSONLParser (`Services/JSONLParser.swift`)
- **Swift Actor** for thread-safe concurrent access
- **Incremental parsing**: Tracks file modification times, only re-parses changed files
- **Directory-level optimization**: Skips entire project directories not modified recently
- **Cache invalidation**: Automatic daily reset at start of new day
- Must be called with `await` from async contexts

#### DataManager (`Services/DataManager.swift`)
- **@MainActor** SwiftData manager with Environment-based injection
- **Auto-recovery**: Detects schema mismatches, deletes corrupted DB, recreates
- **Location**: `~/Library/Application Support/Claudit/claudit-cache.store`
- **Cleanup**: `cleanupOldData(olderThanDays: 90)` removes old entries
- **Error logging**: Logs errors instead of silently swallowing them

#### UsageAPI (`Services/UsageAPI.swift`)
- Fetches quota data from Anthropic API
- Reads OAuth credentials from macOS Keychain (`Claude Code-credentials`)
- **Token expiration handling**: Throws `UsageAPIError.tokenExpired` when credentials expire
- **Honest User-Agent**: Uses `Claudit/1.0 (macOS Usage Tracker)`

#### ExportManager (`Services/ExportManager.swift`)
- CSV export functionality for daily usage, projects, and summary
- Uses `NSSavePanel` for file location selection
- Proper CSV escaping for special characters

#### SettingsManager (`Services/SettingsManager.swift`)
- UserDefaults persistence with Environment-based injection
- Stores: model pricing, display preferences, `hasSeenOnboarding` flag

### State Management

Uses Swift's `@Observable` macro (iOS 17+/macOS 14+) instead of `ObservableObject`:
- `StatsManager` is decorated with `@Observable`
- Views use `@Bindable` for two-way bindings
- Environment injection via custom `EnvironmentKey`:
  - `@Environment(\.statsManager)`
  - `@Environment(\.settingsManager)`
  - `@Environment(\.dataManager)`

### UI Architecture

Four main scenes:

1. **MenuBarExtra** - Popup with quick stats
   - `MenuBarIconView`: Shows cost or quota % in menubar
   - `MenuBarContentView`: Dropdown with quota status, cost summary cards, top projects

2. **Window ("dashboard")** - Detailed analytics with 4 tabs
   - `DashboardView`: Sidebar + TabView with 4 tabs + Export toolbar
   - **Overview Tab**: Daily cost chart, model distribution, daily breakdown table
   - **Projects Tab**: Full project list with search, sort, and time range filtering
   - **Models Tab**: Detailed model cost breakdown with donut chart
   - **Efficiency Tab**: Cache efficiency metrics and AI-powered recommendations

3. **Settings** - Configuration
   - `SettingsView`: Model pricing, privacy info, about section with version

4. **Onboarding** - First launch experience
   - `WelcomeView`: Features overview, requirements check, Keychain access explanation

### Data Models

#### Session Data (JSONL parsing)
- `SessionEntry`: Single JSONL line (Sendable)
- `SessionUsage`: Token counts from API response (Sendable)
- `AggregatedUsage`: Rolled-up token counts by model (Sendable)

#### Processed Data (for UI)
- `DailyCost`: Cost + tokens for one day
- `CumulativeCost`: All-time cost per model
- `ProjectUsage`: Cost breakdown by project directory
  - `StatsManager` maintains three collections: `projectCostsWeek`, `projectCostsMonth`, `projectCostsAllTime`
  - Enables time range filtering in Projects tab

#### SwiftData Models
- `CachedDailyUsage`: Persisted daily aggregates
- `CachedProjectUsage`: Weekly project costs
- `CachedSummary`: Today/week/month/total summary

### Token Formatting

Use `Int.formatTokenCount()` extension (`Utilities/FormatHelpers.swift`):
- Displays K/M/B suffixes (1500 → "1.5K", 1_000_000 → "1.0M")
- Consistent with Dashboard token display

Also available: `Bundle.appVersion` for version display.

### Time Formatting

Use `TimeInterval.formattedDuration` extension (`Utilities/FormatHelpers.swift`):
- Formats seconds into human-readable duration ("2h 30m", "45m", "30s")
- Consistent with quota reset time display

### Performance Logging

Use `PerfLog` utility (`Utilities/PerfLog.swift`) for debugging:
```swift
PerfLog.start("operation")
// ... work ...
PerfLog.end("operation")  // Logs: "⏱ operation: 123.4ms"
```

**Thread-safe**: Uses `NSLock` for concurrent access. Only enabled in DEBUG builds.

## Critical Implementation Patterns

### Adding New Computed Properties to StatsManager

When exposing new metrics, follow this pattern:

```swift
// In StatsManager.swift
var newMetric: Double {
    let usage = aggregatedUsage(since: Date().startOfWeek)
    return usage.someCalculation()
}
```

Always use `aggregatedUsage(since:)` for date ranges - it merges JSONL + SwiftData correctly.

### Working with JSONLParser (Actor)

Since JSONLParser is an actor, all calls must be async:

```swift
// Correct - await actor methods
let usage = await parser.dailyUsage(from: startDate, to: endDate)
let projects = await parser.usageByProject(from: startDate, to: endDate)

// In StatsManager, use Task.detached for background work
Task.detached {
    let parser = JSONLParser()
    let results = await parser.dailyUsage(from: start, to: end)
    await MainActor.run {
        self.updateUI(with: results)
    }
}
```

### Time Range Filtering Pattern

Projects tab uses multi-range data parsing (Week/Month/All Time). Pattern:

**In StatsManager:**
```swift
// Store separate collections for each time range
private(set) var projectCostsWeek: [ProjectUsage] = []
private(set) var projectCostsMonth: [ProjectUsage] = []
private(set) var projectCostsAllTime: [ProjectUsage] = []

// Parse during background load (async)
let weekProjects = await parser.usageByProject(from: weekStart, to: endDate)
let monthProjects = await parser.usageByProject(from: monthStart, to: endDate)
let allTimeProjects = await parser.usageByProject(from: Date.distantPast, to: endDate)
```

**In View:**
```swift
@Binding var selectedTimeRange: DashboardView.TimeRange

private var dataForTimeRange: [SomeData] {
    switch selectedTimeRange {
    case .week: return statsManager?.weekData ?? []
    case .month: return statsManager?.monthData ?? []
    case .all: return statsManager?.allTimeData ?? []
    }
}
```

### Updating UI Components

1. **MenuBar**: Modify `MenuBarContentView.swift` subviews (CostCard, QuotaRow, etc.)
2. **Dashboard**: Update `DashboardView.swift` sidebar or detail pane
3. **Token display**: Use `.formatTokenCount()` and `.caption2` + `.secondary` style

### SwiftData Schema Changes

When modifying `@Model` classes in `Models/CachedData.swift`:
1. Change the model
2. Delete old database: `rm -rf ~/Library/Application\ Support/Claudit/claudit-cache.store*`
3. Restart app - `DataManager` will auto-recreate with new schema

**Future-proof**: `DataManager.init()` already has auto-recovery for schema mismatches.

### Environment-Based Dependency Injection

Services use custom `EnvironmentKey` for injection:

```swift
// Define key
struct SettingsManagerKey: EnvironmentKey {
    static let defaultValue: SettingsManager? = nil
}

extension EnvironmentValues {
    var settingsManager: SettingsManager? {
        get { self[SettingsManagerKey.self] }
        set { self[SettingsManagerKey.self] = newValue }
    }
}

// Use in views
@Environment(\.settingsManager) private var settings
```

### Menubar Actions (Window Activation)

When opening windows from menubar, activate app BEFORE dismissing:
```swift
openWindow(id: "dashboard")
NSApp.activate(ignoringOtherApps: true)  // Bring to front FIRST
dismiss()  // THEN dismiss menu
```

## File Organization

```
Claudit/
├── ClauditApp.swift              # App entry point, MenuBarExtra + Windows
├── Models/
│   ├── SessionEntry.swift        # JSONL parsing models + AggregatedUsage (Sendable)
│   ├── UsageData.swift           # DailyCost, CumulativeCost (UI models)
│   ├── CachedData.swift          # SwiftData @Model classes
│   ├── ModelPricing.swift        # ClaudeModel enum + pricing
│   ├── Recommendation.swift      # AI recommendation models
│   └── UsageResponse.swift       # Anthropic API response models
├── Services/
│   ├── StatsManager.swift        # Central @Observable data coordinator
│   ├── JSONLParser.swift         # Swift Actor for JSONL file parsing
│   ├── DataManager.swift         # SwiftData manager with Environment injection
│   ├── SettingsManager.swift     # UserDefaults with Environment injection
│   ├── UsageAPI.swift            # Anthropic API + Keychain access
│   └── ExportManager.swift       # CSV export functionality
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarIconView.swift      # Menubar indicator
│   │   └── MenuBarContentView.swift   # Popup menu content
│   ├── Dashboard/
│   │   ├── DashboardView.swift        # Main window with tabs + export
│   │   ├── OverviewTabView.swift      # Tab 1: Charts and daily breakdown
│   │   ├── ProjectsTabView.swift      # Tab 2: Project list with time filter
│   │   ├── ModelsTabView.swift        # Tab 3: Model cost breakdown
│   │   ├── EfficiencyTabView.swift    # Tab 4: Cache efficiency
│   │   ├── CostChartView.swift        # Swift Charts bar chart
│   │   └── ModelBreakdownView.swift   # Donut chart component
│   ├── Settings/
│   │   └── SettingsView.swift         # Config, Privacy, About
│   └── Onboarding/
│       └── WelcomeView.swift          # First launch experience
├── Utilities/
│   ├── DateFormatters.swift           # Shared formatters
│   ├── PerfLog.swift                  # Performance logging
│   └── FormatHelpers.swift            # Token/time formatting, Bundle.appVersion
└── scripts/
    ├── notarize.sh                    # Build, sign, notarize, DMG script
    └── ExportOptions.plist            # Archive export configuration
```

## Data Sources

1. **JSONL Session Files**: `~/.claude/projects/*/[session].jsonl`
   - Real-time token usage with cache breakdown
   - Session IDs, project paths (cwd), timestamps
   - Message content (for recommendations)

2. **SwiftData Cache**: `~/Library/Application Support/Claudit/claudit-cache.store`
   - Historical daily usage (60+ days)
   - Project costs (current week)
   - Summary metrics

3. **Anthropic API**: `https://api.anthropic.com/v1/usage`
   - Real-time quota utilization (5-hour, 7-day)
   - Per-model quotas (Sonnet, Opus)
   - Reset timestamps

4. **macOS Keychain**: `Claude Code-credentials`
   - OAuth token for API authentication
   - Read-only access (created by Claude Code)

## Common Patterns

### Color Coding for Quotas
```swift
func quotaColor(for percent: Int) -> QuotaColor {
    if percent >= 90 { return .red }
    if percent >= 75 { return .yellow }
    return .green
}
```

### System Colors (Dark Mode Support)
Always use system colors:
```swift
Color(nsColor: .controlBackgroundColor)
Color(nsColor: .textBackgroundColor)
Color(nsColor: .separatorColor)
```

### Error Handling
Log errors instead of silently swallowing:
```swift
do {
    try await someOperation()
} catch {
    print("Operation failed: \(error)")
    // Handle gracefully in UI
}
```

## Future Features

See `FEATURE_IDEAS.md` for roadmap:
- **Phase 2**: Session cost tracking, heatmaps, quota forecasting
- **Phase 3**: Iteration counting, prompt analysis, learning insights

When implementing new features, prefer incremental updates to `StatsManager` computed properties over architectural changes.

## Debugging

### Performance Issues
Check `PerfLog` output in Xcode console:
```
⏱ appInit: 58.2ms
⏱ jsonlParsing: 1342.7ms
⏱ parseAndUpdateSwiftData: 4123.5ms
```

### SwiftData Issues
Delete cache and rebuild:
```bash
rm -rf ~/Library/Application\ Support/Claudit/claudit-cache.store*
```

### JSONL Parsing Issues
Check file access:
```bash
ls -la ~/.claude/projects/
```

### Token/Keychain Issues
If quota fetching fails with token expiration:
1. Restart Claude Code CLI
2. Sign in again
3. Relaunch Claudit

### Actor Isolation Warnings
The codebase has some Swift 6 actor isolation warnings. These are non-blocking but should be addressed for full Swift 6 compatibility:
- `SessionEntry` and related models are `@MainActor` isolated
- `JSONLParser` actor methods calling `@MainActor` code need proper isolation
