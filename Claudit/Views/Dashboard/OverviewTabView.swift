import SwiftUI
import Charts

struct OverviewTabView: View {
    let statsManager: StatsManager?
    @Binding var selectedTimeRange: DashboardView.TimeRange

    var filteredCosts: [DailyCost] {
        guard let costs = statsManager?.dailyCosts else { return [] }
        guard let days = selectedTimeRange.days else { return costs }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return costs.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(DashboardView.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Cost Chart
                CostChartView(dailyCosts: filteredCosts)
                    .frame(height: 300)
                    .padding()

                // Model Breakdown Chart
                if let costs = statsManager?.cumulativeCosts, !costs.isEmpty {
                    ModelBreakdownView(costs: costs)
                        .frame(height: 250)
                        .padding()
                }

                // Daily Details Table
                DailyDetailsTable(dailyCosts: filteredCosts)
                    .padding()
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
