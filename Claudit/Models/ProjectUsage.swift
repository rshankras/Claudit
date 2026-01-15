import Foundation

/// Represents usage and cost for a single project (by working directory)
struct ProjectUsage: Identifiable, Sendable {
    let projectPath: String
    var usage: AggregatedUsage
    var cachedCost: Double?  // Used when loading from SwiftData

    var id: String { projectPath }

    /// Project name (last path component)
    var projectName: String {
        (projectPath as NSString).lastPathComponent
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
