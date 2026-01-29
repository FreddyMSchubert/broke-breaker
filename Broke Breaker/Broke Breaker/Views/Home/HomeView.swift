//
//  ContentView.swift
//  practice
//
//  Created by Faith Oyemike on 27/01/2026.
//

import SwiftUI

struct ContentView: View {
    // Defines a screen in SwiftUI — every screen is a struct that conforms to View

    // MARK: - UI MOCK DATA (FAKE DATA JUST FOR DESIGN PREVIEW)

    let dailyBudget: Double = 20
    // Pretend daily budget — backend will replace this later

    let dailySpendings: [Double] = [18, 22, 15, 19, 25]
    // Fake spending data for different days to design the UI layout

    let days: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    // Labels for each day shown on the interface

    var body: some View {
        ScrollView {
            // Allows scrolling if screen content becomes too tall

            VStack(spacing: 30) {
                // Vertically stacks UI sections with space between them

                // MARK: - PAGE TITLE
                Text("Spending Overview")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Makes the title large and aligned to the left like a dashboard

                // MARK: - TODAY SUMMARY CARD
                VStack(alignment: .leading, spacing: 12) {

                    Text("Today's Spending")
                        .font(.headline)
                        // Section heading

                    let todaySpending = dailySpendings.last ?? 0
                    // Gets the most recent day’s spending (UI mock)

                    Text("£\(todaySpending, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(todaySpending <= dailyBudget ? .green : .red)
                        // Green if under budget, red if over budget

                    Text(todaySpending <= dailyBudget
                         ? "You're within budget today ✅"
                         : "You've exceeded today's budget ⚠️")
                    // Text feedback based purely on UI condition
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 4)
                // Creates a soft card-style container

                // MARK: - WEEKLY FLOW CHART SECTION
                VStack(alignment: .leading, spacing: 16) {

                    Text("Daily Spending Trend")
                        .font(.headline)
                        // Explains what the chart represents

                    FlowAreaChart(values: dailySpendings, budget: dailyBudget)
                        .frame(height: 200)
                        // Fixed height so chart looks balanced
                }

                Spacer()
                // Pushes everything upward for clean spacing
            }
            .padding()
            // Adds space from screen edges
        }
    }
}

#Preview {
    ContentView()
}
//📈 FLOW CHART (UI-ONLY — NO BACKEND)
struct FlowAreaChart: View {
    // A reusable visual component that draws a flowing spending chart

    let values: [Double]
    // Array of spending amounts for each day (UI mock data)

    let budget: Double
    // Daily budget used only for visual comparison

    var body: some View {

        GeometryReader { geo in
            // Gives access to available width and height so chart scales properly

            let maxValue = max(values.max() ?? 1, budget)
            // Finds the highest value between spending and budget
            // Used to scale the chart vertically

            ZStack {

                // MARK: - FILLED SPENDING AREA
                Path { path in

                    for index in values.indices {
                        // Loops through every day’s spending value

                        let x = geo.size.width / CGFloat(values.count - 1) * CGFloat(index)
                        // Spreads points evenly across the width of the chart

                        let y = geo.size.height - (geo.size.height * CGFloat(values[index] / maxValue))
                        // Converts spending amount into vertical screen position
                        // Bigger spending = higher point on chart

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                            // Starts the drawing path at the first data point
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                            // Draws straight lines connecting points
                        }
                    }

                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    // Drops line down to bottom-right corner

                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    // Draws line to bottom-left corner

                    path.closeSubpath()
                    // Closes shape so it can be filled
                }
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .blue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Applies a soft vertical gradient fill

                // MARK: - SPENDING LINE
                Path { path in

                    for index in values.indices {

                        let x = geo.size.width / CGFloat(values.count - 1) * CGFloat(index)
                        let y = geo.size.height - (geo.size.height * CGFloat(values[index] / maxValue))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(.blue, lineWidth: 3)
                // Draws the top trend line
            }
        }
    }
}
