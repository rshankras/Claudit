import SwiftUI

struct EfficiencyTabView: View {
    let statsManager: StatsManager?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cache Efficiency Section
                GroupBox {
                    if let manager = statsManager {
                        HStack(spacing: 40) {
                            // Today's cache efficiency
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Today")
                                    .font(.headline)
                                Text("\(manager.todayCacheHitPercent)%")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(cacheHitColor(manager.todayCacheHitPercent))
                                Text("hit rate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if manager.todayCacheSavings > 0 {
                                    Text("Saved \(String(format: "$%.2f", manager.todayCacheSavings))")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()

                            // This week's cache efficiency
                            VStack(alignment: .leading, spacing: 8) {
                                Text("This Week")
                                    .font(.headline)
                                Text("\(manager.weekCacheHitPercent)%")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(cacheHitColor(manager.weekCacheHitPercent))
                                Text("hit rate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if manager.weekCacheSavings > 0 {
                                    Text("Saved \(String(format: "$%.2f", manager.weekCacheSavings))")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    } else {
                        Text("No cache data")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                } label: {
                    Text("Cache Efficiency")
                        .font(.headline)
                }

                // Recommendations Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        if let manager = statsManager, !manager.recommendations.isEmpty {
                            ForEach(manager.recommendations) { rec in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(rec.suggestion)
                                            .font(.headline)
                                        Text(rec.detail)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                        Text("Could save ~\(String(format: "$%.2f", rec.potentialSavings))")
                                            .font(.body)
                                            .foregroundStyle(.green)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title2)
                                Text("No recommendations at this time - your usage is optimized!")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                } label: {
                    Text("Insights & Recommendations")
                        .font(.headline)
                }
            }
            .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func cacheHitColor(_ percent: Int) -> Color {
        if percent >= 60 { return .green }
        if percent >= 30 { return .orange }
        return .red
    }
}
