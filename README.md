# Claudit

A macOS menubar app that tracks your Claude Code usage costs and helps you optimize spending.

> **Note:** Claudit is an independent project and is not affiliated with Anthropic.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Cost Tracking
- **Real-time monitoring**: Track costs for Today, This Week, This Month, and All Time
- **Token usage**: See token counts alongside costs (with K/M/B formatting)
- **Model breakdown**: View spending per model (Opus, Sonnet, Haiku)
- **Project insights**: Identify which projects cost the most with time range filtering (Week/Month/All Time)
- **CSV Export**: Export daily usage, project costs, or summary data

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

## Screenshots

<!-- Add screenshots here -->
<!-- ![Menubar](screenshots/menubar.png) -->
<!-- ![Dashboard](screenshots/dashboard.png) -->

## Requirements

- macOS 14.0 (Sonoma) or later
- Claude Code CLI installed and signed in

## Installation

### Download

Download the latest release from [Releases](../../releases).

1. Open the DMG file
2. Drag Claudit to Applications folder
3. Launch Claudit from Applications
4. Allow Keychain access when prompted (click "Always Allow")

### Build from Source

```bash
git clone https://github.com/rshankras/Claudit.git
cd Claudit
open Claudit.xcodeproj
# Build and run with Cmd+R
```

**Build Requirements:**
- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+ SDK

## Technical Highlights

Claudit demonstrates modern macOS development patterns:

### Architecture
- **Two-tier caching**: SwiftData for instant UI (~58ms load) + real-time JSONL parsing for accuracy
- **Actor-based concurrency**: `JSONLParser` actor ensures thread-safe file access
- **@Observable pattern**: Modern Swift observation without Combine boilerplate
- **Environment injection**: Clean dependency pattern for testability

### Performance Optimizations
- **Incremental parsing**: Only re-parses changed files using modification time tracking
- **Directory-level skipping**: Skips entire project directories not modified recently
- **Parallel loading**: API fetch and JSONL parsing run concurrently
- **Background processing**: Heavy work runs off main thread with `Task.detached`

### Data Sources
1. **JSONL session files** (`~/.claude/projects/*/[session].jsonl`) - Token counts, cache usage
2. **SwiftData cache** - Historical data for fast loading
3. **Anthropic API** - Real-time quota utilization and limits
4. **macOS Keychain** - OAuth credentials (read-only)

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Privacy & Security

Claudit is designed with privacy first:

- **Local Processing**: All cost calculations happen on your Mac
- **No Telemetry**: No analytics, no tracking, no data collection
- **Minimal Network**: Only calls Anthropic API to fetch YOUR quota status
- **Read-only Keychain**: Uses existing Claude Code credentials

### Keychain Access

On first launch, macOS will prompt you to allow access to "Claude Code-credentials" from your Keychain. Click **Always Allow** to grant permanent access.

## Usage

### Menubar Quick View

Click the menubar icon to see:
- **Quota status**: Session and weekly quotas with progress bars
- **Cost summary**: Today, Week, Month, All Time with token counts
- **Top projects**: Top 3-4 projects by cost

### Dashboard

Open the Dashboard for detailed analytics with 4 tabs:

| Tab | Contents |
|-----|----------|
| **Overview** | Daily cost chart, model distribution donut chart, daily breakdown table |
| **Projects** | Full project list with search, sorting, time range filter |
| **Models** | Model breakdown with Input/Output/Cache costs |
| **Efficiency** | Cache hit rates, savings, optimization recommendations |

### Exporting Data

From Dashboard toolbar:
- **Export Daily Usage**: Date, cost, tokens, messages, sessions per day
- **Export Projects**: Project names, paths, costs, token breakdown
- **Export Summary**: Overall statistics and model breakdown

## Troubleshooting

<details>
<summary><strong>No usage data showing</strong></summary>

1. Make sure Claude Code is installed and you've used it
2. Check that `~/.claude/projects/` exists and contains JSONL files
3. Restart the app to trigger a fresh parse
</details>

<details>
<summary><strong>Keychain access denied</strong></summary>

1. Open System Settings > Privacy & Security
2. Re-authorize Claudit when prompted
3. Or delete Claudit from Keychain Access and re-launch
</details>

<details>
<summary><strong>Quota not updating</strong></summary>

1. Your Claude Code session may have expired - restart Claude Code
2. Check your internet connection
3. API quotas refresh every 2 minutes
</details>

<details>
<summary><strong>Database corrupted</strong></summary>

Delete the cache and restart:
```bash
rm -rf ~/Library/Application\ Support/Claudit/claudit-cache.store*
```
The app will rebuild automatically.
</details>

## Roadmap

See [FEATURE_IDEAS.md](FEATURE_IDEAS.md) for future plans:

- **Phase 2**: Session cost tracking, usage heatmaps, week-over-week comparison
- **Phase 3**: Iteration counting, prompt analysis, context efficiency scoring

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Inspiration

Inspired by [CodexBar](https://codexbar.app) - a multi-provider AI usage tracker. Claudit focuses specifically on Claude Code with deeper cost analytics and optimization insights.

## License

MIT License - See [LICENSE](LICENSE) for details.

---

## Author

**Ravi Shankar** - iOS & macOS Developer

- Website: [rshankar.com](https://rshankar.com)
- LinkedIn: [linkedin.com/in/sravis](https://www.linkedin.com/in/sravis/)
- GitHub: [github.com/rshankras](https://github.com/rshankras)

### Looking for an iOS/macOS Developer?

I'm available for freelance and contract work. I specialize in:
- Native iOS and macOS app development
- SwiftUI, SwiftData, and modern Swift patterns
- Menu bar utilities and system integrations
- Local-first, privacy-focused app design

**[Get in touch](mailto:ravi@rshankar.com)** to discuss your project.

---

<p align="center">
  <sub>If you find Claudit useful, consider giving it a star!</sub>
</p>
