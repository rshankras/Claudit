import Foundation
import SwiftUI

enum ClaudeModel: String, CaseIterable, Identifiable, Codable {
    case opus = "claude-opus-4-5-20251101"
    case sonnet = "claude-sonnet-4-5-20250929"
    case haiku = "claude-haiku-4-5-20251001"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus: return "Claude Opus 4.5"
        case .sonnet: return "Claude Sonnet 4.5"
        case .haiku: return "Claude Haiku 4.5"
        }
    }

    var shortName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        }
    }

    var color: Color {
        switch self {
        case .opus: return .purple
        case .sonnet: return .orange
        case .haiku: return .green
        }
    }

    /// Initialize from a model ID string, handling version variations
    init?(modelId: String) {
        // Try exact match first
        if let model = ClaudeModel(rawValue: modelId) {
            self = model
            return
        }

        // Try prefix matching for version variations
        if modelId.hasPrefix("claude-opus-4") {
            self = .opus
        } else if modelId.hasPrefix("claude-sonnet-4") {
            self = .sonnet
        } else if modelId.hasPrefix("claude-haiku-4") {
            self = .haiku
        } else {
            return nil
        }
    }
}

struct ModelPricing: Codable, Equatable, Sendable {
    var inputPer1K: Double
    var outputPer1K: Double
    var cacheReadPer1K: Double
    var cacheWritePer1K: Double

    // Anthropic pricing (per 1K tokens) - divide MTok price by 1000
    // Source: https://claude.com/pricing (January 2026)
    // Cache: write = 1.25x input, read = 10% of input

    static let defaultOpus = ModelPricing(
        inputPer1K: 0.005,       // $5/MTok
        outputPer1K: 0.025,      // $25/MTok
        cacheReadPer1K: 0.0005,  // $0.50/MTok
        cacheWritePer1K: 0.00625 // $6.25/MTok
    )

    static let defaultSonnet = ModelPricing(
        inputPer1K: 0.003,       // $3/MTok (≤200K tokens)
        outputPer1K: 0.015,      // $15/MTok
        cacheReadPer1K: 0.0003,  // $0.30/MTok
        cacheWritePer1K: 0.00375 // $3.75/MTok
    )

    static let defaultHaiku = ModelPricing(
        inputPer1K: 0.001,       // $1/MTok
        outputPer1K: 0.005,      // $5/MTok
        cacheReadPer1K: 0.0001,  // $0.10/MTok
        cacheWritePer1K: 0.00125 // $1.25/MTok
    )

    static func defaultPricing(for model: ClaudeModel) -> ModelPricing {
        switch model {
        case .opus: return .defaultOpus
        case .sonnet: return .defaultSonnet
        case .haiku: return .defaultHaiku
        }
    }
}
