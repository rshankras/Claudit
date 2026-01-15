# Claudit

A macOS menubar app that tracks your Claude Code usage costs and helps you optimize spending.

> **Note:** Claudit is an independent project and is not affiliated with Anthropic.

## Features

### Cost Tracking
- **Real-time monitoring**: Track costs for Today, This Week, This Month, and All Time
- **Token usage**: See token counts alongside costs (with K/M/B formatting)
- **Model breakdown**: View spending per model (Opus, Sonnet, Haiku)
- **Project insights**: Identify which projects cost the most with time range filtering (Week/Month/All Time)
- **CSV Export**: Export daily usage, project costs, or summary data to CSV

### Quota Management
- **Live quota tracking**: Monitor session (5-hour) and weekly quotas via Anthropic API
- **Per-model quotas**: Track Sonnet and Opus limits separately
- **Quota pacing**: Get warnings when you're on track to hit limits before reset
- **Color-coded indicators**: Green (safe), Yellow (warning), Red (critical)

### Cache Efficiency
- **Hit rate tracking**: See how effectively you're using Claude's prompt cache
- **Savings calculation**: Know how much you've saved by caching
- **Today vs Week comparison**: Track cache efficiency over time

### Insights & Recommendations
- **Model suggestions**: Get notified when cheaper models would work for simple tasks
- **Cost optimization**: Identify expensive patterns in your usage
- **Potential savings**: See how much you could save by using different models

## Requirements

- macOS 14.0 (Sonoma) or later
- Claude Code CLI installed and signed in

## Privacy & Data Access

Claudit is designed with privacy first:

- **Local Processing**: All cost calculations happen on your Mac. No data is sent to third parties.
- **What Claudit Reads**:
  - Local JSONL session files (`~/.claude/projects/*/[session].jsonl`)
  - Your Claude Code OAuth token from macOS Keychain (to fetch YOUR quota from Anthropic)
- **What Claudit Sends**: Only your own token to Anthropic's API to retrieve your quota status
- **No Telemetry**: No analytics, no tracking, no data collection

### Keychain Access

On first launch, macOS will prompt you to allow access to "Claude Code-credentials" from your Keychain. Click **Always Allow** to grant permanent access. This is a one-time prompt.

## How It Works

Claudit reads your local Claude Code session files to calculate accurate token usage and costs. It also fetches real-time quota data from the Anthropic API using your existing Claude Code credentials.

**Data sources:**
1. **JSONL session files** - Token counts, cache usage, project paths
2. **SwiftData cache** - Historical data for fast loading
3. **Anthropic API** - Real-time quota utilization and limits

## Installation

### Download (Recommended)

Download the latest signed and notarized DMG from [Releases](https://github.com/anthropics/claudit/releases).

1. Open the DMG file
2. Drag Claudit to Applications folder
3. Launch Claudit from Applications
4. On first launch, complete the onboarding and allow Keychain access when prompted

### From Source

1. Clone the repository:
```bash
git clone https://github.com/anthropics/claudit.git
cd claudit
```

2. Open in Xcode:
```bash
open Claudit.xcodeproj
```

3. Build and run (Cmd+R)

### Build Requirements
- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+ SDK

## Usage

### First Launch

1. Claudit shows a Welcome screen explaining features and requirements
2. Ensure Claude Code is installed and you're signed in
3. Click "Get Started"
4. Allow Keychain access when macOS prompts (click "Always Allow")

### Menubar Quick View

Click the menubar icon to see:
- **Quota status**: Session and weekly quotas with progress bars and reset times
- **Cost summary cards**: Today, Week, Month, All Time with token counts
- **Top projects**: Top 3-4 projects by cost (this week)

### Dashboard Window

Click "Dashboard" in the menubar popup to open detailed analytics with 4 organized tabs:

**Overview Tab**
- Daily cost chart with time range selector (Week/Month/All Time)
- Model distribution donut chart
- Daily breakdown table with cost, tokens, messages, sessions, tool calls

**Projects Tab**
- Full project list with search and sorting
- Time range selector (Week/Month/All Time)
- Shows cost, tokens, and percentage of total for each project

**Models Tab**
- Detailed model breakdown with donut chart
- Comprehensive cost table showing Input, Output, Cache Read, and Cache Write costs
- Token usage breakdown by model

**Efficiency Tab**
- Cache efficiency metrics (today vs week comparison)
- Hit rate percentages and savings calculations
- AI-powered insights and recommendations for cost optimization

### Exporting Data

From the Dashboard, click the Export button in the toolbar to:
- **Export Daily Usage**: CSV with date, cost, tokens, messages, sessions per day
- **Export Projects**: CSV with project names, paths, costs, and token breakdown
- **Export Summary**: CSV with overall statistics and model breakdown

### Settings

Configure:
- **Model Pricing**: Custom pricing per model (defaults provided)
- **Quota Display**: Show quota % or cost in menubar
- **Privacy & Data**: View exactly what data Claudit accesses

## Performance

Claudit is designed for speed:
- **Initial load**: ~58ms (from SwiftData cache)
- **Background parsing**: ~1-2s (parses today's files + project breakdowns)
- **Bootstrap**: ~4-5s (first run parses full month, then caches)

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development documentation.

### Quick Start

```bash
# Build
xcodebuild -project Claudit.xcodeproj -scheme Claudit -configuration Debug build

# Clean
xcodebuild -project Claudit.xcodeproj -scheme Claudit clean
```

### Building for Distribution

To create a signed and notarized DMG:

```bash
# Set environment variables
export TEAM_ID="your-team-id"
export APPLE_ID="your@email.com"
export APP_PASSWORD="app-specific-password"

# Update scripts/ExportOptions.plist with your Team ID

# Run the notarization script
./scripts/notarize.sh
```

This will:
1. Build a Release archive
2. Export and sign the app
3. Submit for notarization
4. Create a notarized DMG

**Prerequisites:**
- Apple Developer Program membership
- Developer ID Application certificate
- App-specific password for notarization

### Architecture

- **SwiftUI** for UI
- **Swift Concurrency** with actors for thread safety
- **SwiftData** for persistent caching
- **@Observable** for state management
- **Swift Charts** for visualizations

## Troubleshooting

### "No usage data" showing

1. Make sure Claude Code is installed and you've used it
2. Check that `~/.claude/projects/` exists and contains JSONL files
3. Restart the app to trigger a fresh parse

### Keychain access denied

1. Open System Settings > Privacy & Security > Full Disk Access
2. Ensure Claudit has access (or re-authorize when prompted)
3. Alternatively, delete Claudit from Keychain Access and re-launch

### Quota not updating

1. Your Claude Code session may have expired - restart Claude Code and sign in again
2. Check your internet connection
3. API quotas refresh every 5 minutes

### Database corrupted

Delete the cache and restart:
```bash
rm -rf ~/Library/Application\ Support/Claudit/claudit-cache.store*
```

The app will rebuild the cache on next launch.

## Roadmap

See [FEATURE_IDEAS.md](FEATURE_IDEAS.md) for detailed future plans:

### Phase 2: Advanced Tracking
- Session cost tracker (real-time current session cost)
- Daily/hourly usage heatmap
- Cost per conversation/task breakdown
- Week-over-week cost comparison

### Phase 3: Learning & Improvement
- Iteration counter (track task efficiency)
- Prompt length vs success analysis
- Tool usage insights
- Context efficiency scoring

## Inspiration

Inspired by [CodexBar](https://codexbar.app) - a multi-provider AI usage tracker. Claudit focuses specifically on Claude Code with deeper cost analytics and optimization insights.

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you encounter issues or have feature requests:
- GitHub Issues: [github.com/anthropics/claudit/issues](https://github.com/anthropics/claudit/issues)
