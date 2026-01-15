import SwiftUI
import Charts

struct CostChartView: View {
    let dailyCosts: [DailyCost]

    private var maxCost: Double {
        dailyCosts.map(\.totalCost).max() ?? 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Costs")
                .font(.headline)

            if dailyCosts.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No cost data for selected period")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var chart: some View {
        Chart(dailyCosts) { cost in
            BarMark(
                x: .value("Date", cost.date, unit: .day),
                y: .value("Cost", cost.totalCost)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.blue.opacity(0.7), .purple],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let cost = value.as(Double.self) {
                        Text("$\(Int(cost))")
                    }
                }
            }
        }
        .chartYScale(domain: 0...(maxCost * 1.1))
    }
}

#Preview {
    CostChartView(dailyCosts: [
        DailyCost(
            date: Date().addingTimeInterval(-86400 * 6),
            totalCost: 5.20,
            costByModel: [:],
            tokensByModel: [:],
            activity: nil
        ),
        DailyCost(
            date: Date().addingTimeInterval(-86400 * 5),
            totalCost: 8.50,
            costByModel: [:],
            tokensByModel: [:],
            activity: nil
        ),
        DailyCost(
            date: Date().addingTimeInterval(-86400 * 4),
            totalCost: 12.30,
            costByModel: [:],
            tokensByModel: [:],
            activity: nil
        ),
        DailyCost(
            date: Date().addingTimeInterval(-86400 * 3),
            totalCost: 3.80,
            costByModel: [:],
            tokensByModel: [:],
            activity: nil
        ),
        DailyCost(
            date: Date().addingTimeInterval(-86400 * 2),
            totalCost: 15.60,
            costByModel: [:],
            tokensByModel: [:],
            activity: nil
        ),
        DailyCost(
            date: Date().addingTimeInterval(-86400),
            totalCost: 9.20,
            costByModel: [:],
            tokensByModel: [:],
            activity: nil
        ),
        DailyCost(
            date: Date(),
            totalCost: 6.40,
            costByModel: [:],
            tokensByModel: [:],
            activity: nil
        )
    ])
    .frame(width: 600, height: 350)
    .padding()
}
