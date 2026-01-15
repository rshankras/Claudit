import Foundation

@Observable
@MainActor
final class StatsManager {
    // Raw data
    private(set) var stats: ClaudeStatsCache?

    // Processed data
    private(set) var dailyCosts: [DailyCost] = []
    private(set) var cumulativeCosts: [CumulativeCost] = []

    // Real-time data from JSONL (includes historical)
    private(set) var todayUsage: AggregatedUsage = AggregatedUsage()
    private(set) var dailyUsageFromJSONL: [Date: AggregatedUsage] = [:]

    // Project breakdown by time range
    private(set) var projectCostsWeek: [ProjectUsage] = []    // 7 days
    private(set) var projectCostsMonth: [ProjectUsage] = []   // 30 days
    private(set) var projectCostsAllTime: [ProjectUsage] = [] // All time

    // Legacy alias for backward compatibility
    var projectCosts: [ProjectUsage] { projectCostsWeek }

    // Model usage recommendations (today)
    private(set) var recommendations: [ModelRecommendation] = []

    // Summary
    private(set) var todayCost: Double = 0
    private(set) var weekCost: Double = 0
    private(set) var monthCost: Double = 0
    private(set) var totalCost: Double = 0

    // Real quota from Anthropic API
    private(set) var usageResponse: UsageResponse?
    private(set) var usageError: String?
    private(set) var subscriptionType: String?

    // Session quota (5-hour rolling)
    var sessionUsage: UsageLimit? { usageResponse?.fiveHour }
    var sessionPercent: Int { sessionUsage?.utilizationPercent ?? 0 }

    // Weekly quota (all models)
    var weeklyUsage: UsageLimit? { usageResponse?.sevenDay }
    var weeklyPercent: Int { weeklyUsage?.utilizationPercent ?? 0 }

    // Weekly Sonnet quota
    var sonnetUsage: UsageLimit? { usageResponse?.sevenDaySonnet }
    var sonnetPercent: Int { sonnetUsage?.utilizationPercent ?? 0 }

    // Weekly Opus quota
    var opusUsage: UsageLimit? { usageResponse?.sevenDayOpus }
    var opusPercent: Int { opusUsage?.utilizationPercent ?? 0 }

    // Extra usage
    var extraUsage: ExtraUsage? { usageResponse?.extraUsage }

    // Quota pacing
    enum PacingStatus {
        case safe       // Projected to stay under limit
        case warning    // Projected to hit limit before reset
        case critical   // Will hit limit very soon (< 6 hours)
    }

    /// Hours until weekly quota resets
    var hoursUntilWeeklyReset: Double? {
        guard let resetDate = weeklyUsage?.resetsAtDate else { return nil }
        return resetDate.timeIntervalSinceNow / 3600.0
    }

    /// Projected hours until hitting 100% quota at current pace
    var projectedHoursToLimit: Double? {
        guard let weekly = weeklyUsage,
              let resetDate = weekly.resetsAtDate else { return nil }

        let currentPercent = weekly.utilization
        guard currentPercent > 0 else { return nil }  // Can't project if no usage

        // Calculate hours since the start of the quota period (7 days before reset)
        let periodStart = resetDate.addingTimeInterval(-7 * 24 * 3600)
        let hoursSinceStart = Date().timeIntervalSince(periodStart) / 3600.0

        guard hoursSinceStart > 0 else { return nil }

        // Burn rate = percent per hour
        let burnRate = currentPercent / hoursSinceStart

        // Hours to reach 100%
        let remainingPercent = 100.0 - currentPercent
        if remainingPercent <= 0 { return 0 }  // Already at or over limit

        return remainingPercent / burnRate
    }

    /// Current pacing status
    var quotaPacingStatus: PacingStatus {
        guard let projected = projectedHoursToLimit,
              let reset = hoursUntilWeeklyReset else { return .safe }

        // If projected to hit limit before reset, we have a problem
        if projected <= 6 { return .critical }
        if projected < reset { return .warning }
        return .safe
    }

    /// Formatted pacing message for UI
    var pacingMessage: String? {
        guard let projected = projectedHoursToLimit,
              let reset = hoursUntilWeeklyReset else { return nil }

        let status = quotaPacingStatus

        switch status {
        case .safe:
            return nil  // No message needed when safe
        case .warning:
            let projectedFormatted = formatHours(projected)
            let resetFormatted = formatHours(reset)
            return "~\(projectedFormatted) until limit (resets \(resetFormatted))"
        case .critical:
            let projectedFormatted = formatHours(projected)
            return "Critical: ~\(projectedFormatted) until limit!"
        }
    }

    private func formatHours(_ hours: Double) -> String {
        (hours * 3600.0).formattedDuration
    }

    // Cache efficiency (today)
    var todayCacheHitPercent: Int { todayUsage.cacheHitPercent }
    var todayCacheSavings: Double {
        todayUsage.cacheSavings(using: SettingsManager.shared.modelPricing)
    }

    // Cache efficiency (this week)
    var weekCacheHitPercent: Int {
        let weekUsage = aggregatedUsage(since: Date().startOfWeek)
        return weekUsage.cacheHitPercent
    }
    var weekCacheSavings: Double {
        let weekUsage = aggregatedUsage(since: Date().startOfWeek)
        return weekUsage.cacheSavings(using: SettingsManager.shared.modelPricing)
    }

    // MARK: - Token Totals

    var todayTokens: Int {
        todayUsage.inputTokens + todayUsage.outputTokens +
        todayUsage.cacheReadTokens + todayUsage.cacheWriteTokens
    }

    var weekTokens: Int {
        let usage = aggregatedUsage(since: Date().startOfWeek)
        return usage.inputTokens + usage.outputTokens +
               usage.cacheReadTokens + usage.cacheWriteTokens
    }

    var monthTokens: Int {
        let usage = aggregatedUsage(since: Date().startOfMonth)
        return usage.inputTokens + usage.outputTokens +
               usage.cacheReadTokens + usage.cacheWriteTokens
    }

    var totalTokens: Int {
        // Sum from cumulative costs
        cumulativeCosts.reduce(0) { total, cost in
            total + cost.usage.totalTokens
        }
    }

    /// Get aggregated usage since a specific date (combines JSONL + SwiftData)
    private func aggregatedUsage(since startDate: Date) -> AggregatedUsage {
        var result = AggregatedUsage()
        let calendar = Calendar.current

        // First, add data from SwiftData (historical)
        let cachedDaily = DataManager.shared.getDailyUsage(from: startDate, to: Date())
        for cached in cachedDaily {
            // Skip if we have fresh JSONL data for this day
            let hasJSONLData = dailyUsageFromJSONL.keys.contains { calendar.isDate($0, inSameDayAs: cached.date) }
            if hasJSONLData { continue }

            result.inputTokens += cached.inputTokens
            result.outputTokens += cached.outputTokens
            result.cacheReadTokens += cached.cacheReadTokens
            result.cacheWriteTokens += cached.cacheWriteTokens
        }

        // Then add fresh JSONL data (today and any other parsed days)
        for (date, usage) in dailyUsageFromJSONL where date >= startDate {
            result.inputTokens += usage.inputTokens
            result.outputTokens += usage.outputTokens
            result.cacheReadTokens += usage.cacheReadTokens
            result.cacheWriteTokens += usage.cacheWriteTokens
            for (model, tokens) in usage.byModel {
                var existing = result.byModel[model] ?? ModelTokens()
                existing.inputTokens += tokens.inputTokens
                existing.outputTokens += tokens.outputTokens
                existing.cacheReadTokens += tokens.cacheReadTokens
                existing.cacheWriteTokens += tokens.cacheWriteTokens
                result.byModel[model] = existing
            }
        }
        return result
    }

    // Color coding for quota display
    func quotaColor(for percent: Int) -> QuotaColor {
        if percent >= 90 { return .red }
        if percent >= 75 { return .yellow }
        return .green
    }

    enum QuotaColor {
        case green, yellow, red
    }

    // State
    private(set) var lastUpdated: Date?
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false

    private let statsFilePath: String
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pricingObserver: (any NSObjectProtocol)?
    private var refreshTimer: Timer?

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        self.statsFilePath = "\(homeDir)/.claude/stats-cache.json"

        // Listen for pricing changes
        pricingObserver = NotificationCenter.default.addObserver(
            forName: .pricingChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.calculateCosts()
            }
        }
    }

    /// Call this before the StatsManager is deallocated to clean up resources
    func cleanup() {
        if let observer = pricingObserver {
            NotificationCenter.default.removeObserver(observer)
            pricingObserver = nil
        }
        stopWatching()
    }

    func startWatching() {
        loadStats()
        setupFileWatcher()
        startPeriodicRefresh()

        // Initial API fetch
        Task {
            await fetchUsageFromAPI()
        }
    }

    func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    func loadStats() {
        // 1. Load from SwiftData immediately (instant, no parsing)
        loadFromSwiftData()

        // 2. Load cached stats file (small, OK on main thread)
        do {
            let url = URL(fileURLWithPath: statsFilePath)
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ClaudeStatsCache.self, from: data)
            self.stats = decoded
        } catch {
            errorMessage = "Failed to load stats: \(error.localizedDescription)"
        }

        // 3. Run API call and JSONL parsing in PARALLEL (both in background)
        isLoading = true

        // API call (fire and forget - doesn't block UI)
        Task.detached(priority: .utility) { [weak self] in
            await self?.fetchUsageFromAPI()
        }

        // JSONL parsing (separate task, also background)
        Task.detached(priority: .utility) { [weak self] in
            await self?.parseAndUpdateSwiftData()
        }
    }

    /// Load cached data from SwiftData (instant)
    private func loadFromSwiftData() {
        let dataManager = DataManager.shared

        // Load summary
        let summary = dataManager.getSummary()
        self.todayCost = summary.todayCost
        self.weekCost = summary.weekCost
        self.monthCost = summary.monthCost
        self.totalCost = summary.totalCost

        // Load daily costs
        let startDate = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let cachedDaily = dataManager.getDailyUsage(from: startDate, to: Date())
        self.dailyCosts = cachedDaily.map { cached in
            DailyCost(
                date: cached.date,
                totalCost: cached.totalCost,
                costByModel: cached.costByModel,
                tokensByModel: [:],
                activity: nil
            )
        }

        // Load project costs (use cached cost from SwiftData)
        let cachedProjects = dataManager.getProjectUsage()
        self.projectCostsWeek = cachedProjects.map { cached in
            var usage = AggregatedUsage()
            usage.inputTokens = cached.inputTokens
            usage.outputTokens = cached.outputTokens
            return ProjectUsage(
                projectPath: cached.projectPath,
                usage: usage,
                cachedCost: cached.totalCost  // Use pre-calculated cost from SwiftData
            )
        }

        self.lastUpdated = summary.lastUpdated
    }

    /// Parse JSONL files and update SwiftData (background)
    @MainActor
    private func parseAndUpdateSwiftData() async {
        let pricing = SettingsManager.shared.modelPricing
        let dataManager = DataManager.shared

        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let today = calendar.startOfDay(for: Date())
        let weekStart = Date().startOfWeek
        let monthStart = Date().startOfMonth

        // Check if we need to bootstrap historical data (less than 7 days in SwiftData)
        let needsBootstrap = dailyCosts.count < 7

        // Parse in background with a fresh parser instance
        let result = await Task.detached(priority: .utility) {
            let parser = JSONLParser()

            // Daily usage: if bootstrapping, parse full month; otherwise just today
            let dailyStart = needsBootstrap ? monthStart : today
            let dailyUsage = await parser.dailyUsage(from: dailyStart, to: endDate)

            // Project usage: parse for WEEK, MONTH, and ALL TIME
            let weekProjects = await parser.usageByProject(from: weekStart, to: endDate)
            let monthProjects = await parser.usageByProject(from: monthStart, to: endDate)
            let allTimeProjects = await parser.usageByProject(from: Date.distantPast, to: endDate)

            // Recommendations: parse only TODAY
            let todayEntries = await parser.entries(from: today, to: endDate)

            // Analyze recommendations
            var recommendations: [ModelRecommendation] = []
            var smallTasksByModel: [ClaudeModel: [(outputTokens: Int, inputTokens: Int, cost: Double)]] = [:]

            for entry in todayEntries {
                guard entry.isAssistantMessage,
                      let usage = entry.message?.usage,
                      let modelId = entry.message?.model,
                      let model = ClaudeModel(modelId: modelId) else { continue }

                let outputTokens = usage.outputTokens
                if outputTokens < 500 && (model == .opus || model == .sonnet) {
                    guard let price = pricing[model] else { continue }
                    let inputTokens = usage.inputTokens + usage.totalCacheRead + usage.totalCacheWrite
                    let taskCost = Double(inputTokens) / 1000.0 * price.inputPer1K +
                                   Double(outputTokens) / 1000.0 * price.outputPer1K
                    var tasks = smallTasksByModel[model] ?? []
                    tasks.append((outputTokens, inputTokens, taskCost))
                    smallTasksByModel[model] = tasks
                }
            }

            // Generate Opus -> Haiku recommendation
            if let opusTasks = smallTasksByModel[.opus], opusTasks.count >= 3,
               let haikuPrice = pricing[.haiku] {
                let totalOpusCost = opusTasks.reduce(0) { $0 + $1.cost }
                let haikuCost = opusTasks.reduce(0.0) { total, task in
                    total + Double(task.inputTokens) / 1000.0 * haikuPrice.inputPer1K +
                           Double(task.outputTokens) / 1000.0 * haikuPrice.outputPer1K
                }
                let savings = totalOpusCost - haikuCost
                if savings > 0.10 {
                    recommendations.append(ModelRecommendation(
                        suggestion: "Use Haiku for small tasks",
                        detail: "\(opusTasks.count) small tasks used Opus",
                        potentialSavings: savings,
                        taskCount: opusTasks.count
                    ))
                }
            }

            // Generate Sonnet -> Haiku recommendation
            if let sonnetTasks = smallTasksByModel[.sonnet], sonnetTasks.count >= 5,
               let haikuPrice = pricing[.haiku] {
                let totalSonnetCost = sonnetTasks.reduce(0) { $0 + $1.cost }
                let haikuCost = sonnetTasks.reduce(0.0) { total, task in
                    total + Double(task.inputTokens) / 1000.0 * haikuPrice.inputPer1K +
                           Double(task.outputTokens) / 1000.0 * haikuPrice.outputPer1K
                }
                let savings = totalSonnetCost - haikuCost
                if savings > 0.10 {
                    recommendations.append(ModelRecommendation(
                        suggestion: "Use Haiku for small tasks",
                        detail: "\(sonnetTasks.count) small tasks used Sonnet",
                        potentialSavings: savings,
                        taskCount: sonnetTasks.count
                    ))
                }
            }

            return (dailyUsage, weekProjects, monthProjects, allTimeProjects, recommendations)
        }.value

        // Update SwiftData
        dataManager.batchUpdateDailyUsage(result.0, pricing: pricing)
        dataManager.replaceProjectUsage(result.1, pricing: pricing)  // Save weekly projects only

        // Update in-memory state
        self.dailyUsageFromJSONL = result.0
        self.todayUsage = result.0[today] ?? AggregatedUsage()

        // Update project costs for all time ranges
        self.projectCostsWeek = result.1.map { (path, usage) in
            ProjectUsage(projectPath: path, usage: usage)
        }.sorted { $0.cost(using: pricing) > $1.cost(using: pricing) }

        self.projectCostsMonth = result.2.map { (path, usage) in
            ProjectUsage(projectPath: path, usage: usage)
        }.sorted { $0.cost(using: pricing) > $1.cost(using: pricing) }

        self.projectCostsAllTime = result.3.map { (path, usage) in
            ProjectUsage(projectPath: path, usage: usage)
        }.sorted { $0.cost(using: pricing) > $1.cost(using: pricing) }

        self.recommendations = result.4

        // Recalculate costs
        calculateCosts()

        // Update SwiftData summary
        dataManager.updateSummary(
            todayCost: todayCost,
            weekCost: weekCost,
            monthCost: monthCost,
            totalCost: totalCost,
            todayCacheHitPercent: todayCacheHitPercent,
            weekCacheHitPercent: weekCacheHitPercent,
            todayCacheSavings: todayCacheSavings,
            weekCacheSavings: weekCacheSavings
        )

        // Reload from SwiftData to get consistent view
        loadFromSwiftData()
        self.isLoading = false
        self.lastUpdated = Date()
    }

    /// Periodically refresh usage data
    private func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.isLoading == false else { return }
                await self?.parseAndUpdateSwiftData()
                await self?.fetchUsageFromAPI()
            }
        }
    }

    /// Fetch real-time usage from Anthropic API
    func fetchUsageFromAPI() async {
        do {
            let response = try await UsageAPI.fetchUsage()
            self.usageResponse = response
            self.usageError = nil
            self.subscriptionType = UsageAPI.getSubscriptionType()

            NotificationManager.shared.checkAndSendAlerts(for: response)
        } catch {
            self.usageError = error.localizedDescription
        }
    }

    private func setupFileWatcher() {
        // Close existing watcher if any
        fileWatcher?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }

        fileDescriptor = open(statsFilePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            errorMessage = "Cannot watch stats file"
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            // Debounce rapid updates (3 seconds to avoid excessive reloads)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard self?.isLoading == false else { return }
                await self?.parseAndUpdateSwiftData()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source.resume()
        fileWatcher = source
    }

    private func calculateCosts() {
        let settings = SettingsManager.shared
        let pricing = settings.modelPricing
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate today's cost from JSONL data
        todayCost = todayUsage.cost(using: pricing)

        // Update daily costs from JSONL data (merge with SwiftData history)
        for (date, usage) in dailyUsageFromJSONL {
            var tokensByModel: [ClaudeModel: Int] = [:]
            for (model, tokens) in usage.byModel {
                tokensByModel[model] = tokens.inputTokens + tokens.outputTokens +
                                       tokens.cacheReadTokens + tokens.cacheWriteTokens
            }

            let dailyCost = DailyCost(
                date: date,
                totalCost: usage.cost(using: pricing),
                costByModel: usage.costByModel(using: pricing),
                tokensByModel: tokensByModel,
                activity: nil
            )

            // Remove existing entry for this date and add fresh one
            dailyCosts.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
            dailyCosts.append(dailyCost)
        }
        dailyCosts.sort { $0.date > $1.date }

        // Calculate cumulative costs per model from cache (for all-time stats)
        if let stats = stats {
            let calculator = CostCalculator(pricing: pricing)

            cumulativeCosts = stats.modelUsage.compactMap { (modelId, usage) in
                guard let model = ClaudeModel(modelId: modelId) else { return nil }
                let breakdown = calculator.calculateCostBreakdown(for: usage, model: model)

                return CumulativeCost(
                    model: model,
                    totalCost: breakdown.total,
                    breakdown: breakdown,
                    usage: usage
                )
            }.sorted { $0.totalCost > $1.totalCost }
        }

        // Calculate period costs from daily costs (SwiftData history + today's fresh data)
        let now = Date()
        let startOfWeek = now.startOfWeek
        let startOfMonth = now.startOfMonth

        weekCost = dailyCosts.filter { $0.date >= startOfWeek }.reduce(0) { $0 + $1.totalCost }
        monthCost = dailyCosts.filter { $0.date >= startOfMonth }.reduce(0) { $0 + $1.totalCost }

        // All-time: use cumulative from cache + any JSONL days not in cache
        let cumulativeTotal = cumulativeCosts.reduce(0) { $0 + $1.totalCost }
        totalCost = cumulativeTotal + todayCost // Add today since cache is from yesterday
    }
}
