import Foundation
import os.log

/// Parses Claude Code JSONL session files for real-time usage data
/// Thread-safe via Swift actor isolation
actor JSONLParser {
    private let projectsPath: String
    private let decoder = JSONDecoder()
    private let isoFormatter: ISO8601DateFormatter

    // Cache for incremental parsing (actor-isolated, no lock needed)
    private var fileModTimes: [String: Date] = [:]
    private var cachedDailyUsage: [Date: AggregatedUsage] = [:]
    private var lastFullParseDate: Date?

    private static let logger = Logger(subsystem: "com.claudit", category: "parser")

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        self.projectsPath = "\(homeDir)/.claude/projects"

        // Configure ISO8601 formatter for parsing timestamps with Z suffix
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// Get aggregated usage for a specific date (in local timezone)
    func usage(for date: Date) -> AggregatedUsage {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        var aggregated = AggregatedUsage()

        for entry in allEntries(from: startOfDay, to: endOfDay) {
            if entry.isAssistantMessage {
                aggregated.add(entry: entry)
            }
        }

        return aggregated
    }

    /// Get aggregated usage for today
    func todayUsage() -> AggregatedUsage {
        usage(for: Date())
    }

    /// Get aggregated usage for a date range
    func usage(from startDate: Date, to endDate: Date) -> AggregatedUsage {
        var aggregated = AggregatedUsage()

        for entry in allEntries(from: startDate, to: endDate) {
            if entry.isAssistantMessage {
                aggregated.add(entry: entry)
            }
        }

        return aggregated
    }

    /// Get daily usage breakdown for a date range (cached with change detection)
    func dailyUsage(from startDate: Date, to endDate: Date) -> [Date: AggregatedUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if we need a full re-parse (new day or first run)
        if lastFullParseDate != today {
            cachedDailyUsage.removeAll()
            fileModTimes.removeAll()
            lastFullParseDate = today
        }

        // Find files that have changed since last parse
        let changedFiles = findChangedFiles(from: startDate, to: endDate)

        if changedFiles.isEmpty && !cachedDailyUsage.isEmpty {
            return cachedDailyUsage
        }

        // If ANY file changed, we must clear cache and re-parse ALL files
        cachedDailyUsage.removeAll()

        // Parse all recent files
        let allFiles = findAllRecentFiles(from: startDate, to: endDate)
        for filePath in allFiles {
            let entries = parseFile(at: filePath, from: startDate, to: endDate)
            for entry in entries {
                guard entry.isAssistantMessage,
                      let timestamp = parseTimestamp(entry.timestamp) else { continue }

                let dayStart = calendar.startOfDay(for: timestamp)
                var dayUsage = cachedDailyUsage[dayStart] ?? AggregatedUsage()
                dayUsage.add(entry: entry)
                cachedDailyUsage[dayStart] = dayUsage
            }

            // Update mod time for change detection
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
               let modDate = attrs[.modificationDate] as? Date {
                fileModTimes[filePath] = modDate
            }
        }

        return cachedDailyUsage
    }

    /// Find all JSONL files modified within the date range
    /// Optimized: skips directories and files that can't have recent data
    private func findAllRecentFiles(from startDate: Date, to endDate: Date) -> [String] {
        var files: [String] = []

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectsPath) else {
            return files
        }

        for projectDir in projectDirs {
            let projectPath = "\(projectsPath)/\(projectDir)"

            // Quick check: skip entire project directory if not modified recently
            guard let projectAttrs = try? FileManager.default.attributesOfItem(atPath: projectPath),
                  let projectModDate = projectAttrs[.modificationDate] as? Date,
                  projectModDate >= startDate else {
                continue
            }

            guard let dirFiles = try? FileManager.default.contentsOfDirectory(atPath: projectPath) else {
                continue
            }

            for file in dirFiles where file.hasSuffix(".jsonl") {
                let filePath = "\(projectPath)/\(file)"

                guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date else {
                    continue
                }

                if modDate >= startDate {
                    files.append(filePath)
                }
            }
        }

        return files
    }

    /// Find files that have been modified since last check
    private func findChangedFiles(from startDate: Date, to endDate: Date) -> [String] {
        var changedFiles: [String] = []

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectsPath) else {
            return changedFiles
        }

        for projectDir in projectDirs {
            let projectPath = "\(projectsPath)/\(projectDir)"

            // Quick check: skip entire project directory if not modified recently
            guard let projectAttrs = try? FileManager.default.attributesOfItem(atPath: projectPath),
                  let projectModDate = projectAttrs[.modificationDate] as? Date,
                  projectModDate >= startDate else {
                continue
            }

            guard let files = try? FileManager.default.contentsOfDirectory(atPath: projectPath) else {
                continue
            }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = "\(projectPath)/\(file)"

                guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date else {
                    continue
                }

                // Skip old files
                if modDate < startDate { continue }

                // Check if file has changed since last parse (safe optional handling)
                if fileModTimes[filePath].map({ modDate > $0 }) ?? true {
                    changedFiles.append(filePath)
                    fileModTimes[filePath] = modDate
                }
            }
        }

        return changedFiles
    }

    /// Force a full re-parse (clears cache)
    func invalidateCache() {
        cachedDailyUsage.removeAll()
        fileModTimes.removeAll()
        lastFullParseDate = nil
    }

    /// Get usage aggregated by project (cwd) for a date range
    func usageByProject(from startDate: Date, to endDate: Date) -> [String: AggregatedUsage] {
        var projectData: [String: AggregatedUsage] = [:]

        for entry in allEntries(from: startDate, to: endDate) {
            guard entry.isAssistantMessage,
                  let cwd = entry.cwd, !cwd.isEmpty else { continue }

            var projectUsage = projectData[cwd] ?? AggregatedUsage()
            projectUsage.add(entry: entry)
            projectData[cwd] = projectUsage
        }

        return projectData
    }

    /// Get raw entries for a date range (for recommendation analysis)
    func entries(from startDate: Date, to endDate: Date) -> [SessionEntry] {
        allEntries(from: startDate, to: endDate)
    }

    /// Get all entries within a date range from all project JSONL files
    private func allEntries(from startDate: Date, to endDate: Date) -> [SessionEntry] {
        var entries: [SessionEntry] = []

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectsPath) else {
            return entries
        }

        for projectDir in projectDirs {
            let projectPath = "\(projectsPath)/\(projectDir)"

            // Quick check: skip entire project directory if not modified recently
            guard let projectAttrs = try? FileManager.default.attributesOfItem(atPath: projectPath),
                  let projectModDate = projectAttrs[.modificationDate] as? Date,
                  projectModDate >= startDate else {
                continue
            }

            guard let files = try? FileManager.default.contentsOfDirectory(atPath: projectPath) else {
                continue
            }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = "\(projectPath)/\(file)"

                // Quick check: skip files not modified recently
                if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < startDate {
                    continue
                }

                let fileEntries = parseFile(at: filePath, from: startDate, to: endDate)
                entries.append(contentsOf: fileEntries)
            }
        }

        return entries
    }

    /// Parse a single JSONL file and return entries within the date range
    private func parseFile(at path: String, from startDate: Date, to endDate: Date) -> [SessionEntry] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            Self.logger.debug("Could not read file: \(path)")
            return []
        }

        var entries: [SessionEntry] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines where !line.isEmpty {
            guard let data = line.data(using: .utf8) else { continue }

            // Silently skip lines that don't decode to SessionEntry
            // (user messages, system events, summary entries, etc.)
            guard let entry = try? decoder.decode(SessionEntry.self, from: data) else {
                continue
            }

            // Parse timestamp with proper ISO8601 handling
            guard let timestamp = parseTimestamp(entry.timestamp) else {
                continue
            }

            // Compare in local timezone - startDate and endDate are already local
            if timestamp >= startDate && timestamp < endDate {
                entries.append(entry)
            }
        }

        return entries
    }

    /// Parse ISO8601 timestamp string to Date
    private func parseTimestamp(_ string: String) -> Date? {
        // Try with fractional seconds first
        if let date = isoFormatter.date(from: string) {
            return date
        }
        // Fallback without fractional seconds
        let basicFormatter = ISO8601DateFormatter()
        return basicFormatter.date(from: string)
    }
}
