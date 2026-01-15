import Foundation

/// Represents usage and cost for a single project (by working directory)
struct ProjectUsage: Identifiable, Sendable {
    let projectPath: String
    var usage: AggregatedUsage
    var cachedCost: Double?  // Used when loading from SwiftData

    var id: String { projectPath }

    /// Project name (last path component, with special handling for system paths)
    var projectName: String {
        let lastComponent = (projectPath as NSString).lastPathComponent

        // Handle macOS temp directories (e.g., /private/var/folders/.../T)
        if projectPath.contains("/var/folders/") && lastComponent == "T" {
            return "Temp Directory"
        }

        // Handle other single-letter system directories that might be confusing
        if lastComponent.count == 1 && projectPath.contains("/private/") {
            return "System: \(lastComponent)"
        }

        return lastComponent
    }

    /// Calculate cost using provided pricing (or use cached cost from SwiftData)
    func cost(using pricing: [ClaudeModel: ModelPricing]) -> Double {
        // If we have a cached cost (from SwiftData), use it
        if let cached = cachedCost {
            return cached
        }
        // Otherwise calculate from usage
        return usage.cost(using: pricing)
    }
}
