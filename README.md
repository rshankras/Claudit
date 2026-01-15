# Claudit

A macOS menubar app that tracks your Claude Code usage costs and helps you optimize spending.

## Features

### Cost Tracking
- **Real-time monitoring**: Track costs for Today, This Week, This Month, and All Time
- **Token usage**: See token counts alongside costs (with K/M/B formatting)
- **Model breakdown**: View spending per model (Opus, Sonnet, Haiku)
- **Project insights**: Identify which projects cost the most with time range filtering (Week/Month/All Time)
- **Tab-based dashboard**: Organized views for Overview, Projects, Models, and Efficiency

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
- Claude Code CLI installed
- Anthropic API key (for quota tracking)

## How It Works

Claudit reads your local Claude Code session files (`~/.claude/projects/*/[session].jsonl`) to calculate accurate token usage and costs. It also fetches real-time quota data from the Anthropic API.

**Data sources:**
1. **JSONL session files** - Token counts, cache usage, project paths
2. **SwiftData cache** - Historical data for fast loading
3. **Anthropic API** - Real-time quota utilization and limits

**Privacy:** All data is processed locally. Your API key is stored in macOS Keychain.

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/claudit.git
cd claudit
```

2. Open in Xcode:
```bash
open Claudit.xcodeproj
```

3. Build and run (Cmd+R)

### Requirements
- Xcode 15.0+
- Swift 5.9+

## Configuration

### Setting Your API Key

1. Click the Claudit icon in your menubar
2. Select "Settings"
3. Enter your Anthropic API key
4. Configure model pricing (defaults provided)

### Customizing Pricing

If you have custom pricing or want to adjust calculations:
1. Open Settings
2. Go to "Model Pricing"
3. Edit per-1000-token costs for each model

## Usage

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
- Time range selector (Week/Month/All Time) to view project costs over different periods
- Shows cost, tokens, and percentage of total for each project
- Filter projects by name and sort by cost, tokens, or name

**Models Tab**
- Detailed model breakdown with donut chart
- Comprehensive cost table showing Input, Output, Cache Read, and Cache Write costs per model
- Token usage breakdown by model

**Efficiency Tab**
- Cache efficiency metrics (today vs week comparison)
- Hit rate percentages and savings calculations
- AI-powered insights and recommendations for cost optimization

### Settings

Configure:
- **API Key**: Anthropic API key for quota tracking
- **Model Pricing**: Custom pricing per model
- **Quota Display**: Show quota % or cost in menubar

## Performance

Claudit is designed for speed:
- **Initial load**: ~58ms (from SwiftData cache)
- **Background parsing**: ~1-2s (parses today's files + project breakdowns for week/month/all-time)
- **Bootstrap**: ~4-5s (first run parses full month, then caches)

## Roadmap

See [FEATURE_IDEAS.md](FEATURE_IDEAS.md) for detailed future plans:

### Phase 2: Advanced Tracking
- Session cost tracker (real-time current session cost)
- Daily/hourly usage heatmap
- Cost per conversation/task breakdown
- Prominent quota forecasting
- Model auto-switch suggestions
- Week-over-week cost comparison

### Phase 3: Learning & Improvement
- Iteration counter (track task efficiency)
- Prompt length vs success analysis
- Tool usage insights
- Context efficiency scoring
- Prompt pattern library
- Clarification request tracking
- Progress tracking over time
- Personalized best practices nudges

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development documentation.

### Quick Start

```bash
# Build
xcodebuild -project Claudit.xcodeproj -scheme Claudit -configuration Debug build

# Clean
xcodebuild -project Claudit.xcodeproj -scheme Claudit clean
```

### Architecture

- **SwiftUI** for UI
- **Swift Concurrency** for background tasks
- **SwiftData** for persistent caching
- **@Observable** for state management
- **Swift Charts** for visualizations

## Troubleshooting

### "No usage data" showing

1. Make sure Claude Code is installed and you've used it
2. Check that `~/.claude/projects/` exists and contains JSONL files
3. Restart the app to trigger a fresh parse

### Quota not updating

1. Verify your Anthropic API key is set in Settings
2. Check your internet connection
3. API quotas refresh every 5 minutes

### Database corrupted

Delete the cache and restart:
```bash
rm -rf ~/Library/Application\ Support/Claudit/claudit-cache.store*
```

The app will rebuild the cache on next launch.

## Inspiration

Inspired by [CodexBar](https://codexbar.app) - a multi-provider AI usage tracker. Claudit focuses specifically on Claude Code with deeper cost analytics and optimization insights.

## License

[Add your license here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you encounter issues or have feature requests, please open an issue on GitHub.

---

**Note:** Claudit is an independent project and is not affiliated with Anthropic.
