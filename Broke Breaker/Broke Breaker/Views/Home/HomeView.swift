import SwiftUI
import SharedLedger

struct HomeView: View {

    let ledger = Ledger.shared

    @AppStorage("spendPercent") private var spendPercent: Double = 0.7
    @AppStorage("allowanceDays") private var allowanceDays: Int = 3
    @AppStorage("rolloverAllowanceMain") private var rolloverAllowanceMain: Double = 0
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("selectedCurrencyCode") private var currencySelected = "GBP"
    @State private var settingsActive = false

    @State private var dashboard = HomeDashboardData.empty

    private var isNegativeToday: Bool { dashboard.allowedSpendToday < 0 }

    var body: some View {
        ZStack(alignment: .topTrailing) {

            LinearGradient(
                colors: isNegativeToday
                ? [
                    Color(red: 0.22, green: 0.03, blue: 0.07),
                    Color(red: 0.52, green: 0.09, blue: 0.17)
                ]
                : [
                    Color(red: 0.03, green: 0.10, blue: 0.26),
                    Color(red: 0.08, green: 0.21, blue: 0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {

                    HStack {
                        Text("BROKE BREAKER")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(1)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 14) {

                        Text("Balance")
                            .font(.subheadline)
                            .opacity(0.85)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(dashboard.allowedSpendToday.formatted(.currency(code: currencySelected)))
                            .font(.system(size: 40, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .center)

                        Divider()

                        Text("Savings")
                            .font(.subheadline)
                            .opacity(0.85)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(dashboard.savingsBalanceToday.formatted(.currency(code: currencySelected)))
                            .font(.system(size: 40, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .center)

                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .cornerRadius(20)
                    .shadow(radius: 10)

                    VStack(alignment: .leading, spacing: 16) {

                        FlowAreaChart(
                            values: dashboard.allowanceSeries,
                            labels: dashboard.allowanceLabels,
                            isNegativeTheme: isNegativeToday,
                            currencyCode: currencySelected
                        )
                        .frame(height: 220)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: isNegativeToday
                                ? [
                                    Color(red: 0.42, green: 0.08, blue: 0.14).opacity(0.55),
                                    Color(red: 0.22, green: 0.03, blue: 0.07).opacity(0.55)
                                ]
                                : [
                                    Color(red: 0.10, green: 0.20, blue: 0.46).opacity(0.55),
                                    Color(red: 0.04, green: 0.10, blue: 0.26).opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .cornerRadius(20)
                        .shadow(
                            color: isNegativeToday ? .red.opacity(0.28) : .blue.opacity(0.28),
                            radius: 20, x: 0, y: 10
                        )
                    }

                    Spacer(minLength: 12)
                }
                .padding()
                .foregroundColor(.white)
            }

            Button(action: { settingsActive = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect()
            .padding(.top, 10)
            .padding(.trailing, 14)
            .sheet(isPresented: $settingsActive) {
                SettingsView()
            }
        }
        .task { loadDashboardData() }
    }

    private func loadDashboardData() {
        do {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())

            let totalsToday = try ledger.dayTotals(for: today)

            let allowedSpendToday =
                (totalsToday.runningBalanceMainEndOfDay as NSDecimalNumber).doubleValue

            let savingsToday =
                (totalsToday.runningBalanceSavingsEndOfDay as NSDecimalNumber).doubleValue

            let days = max(allowanceDays, 1)
            let offsets = [-1, 0, 1]
            var series: [Double] = []
            var lbls: [String] = []

            var rollover = rolloverAllowanceMain

            for off in offsets {
                let d = cal.date(byAdding: .day, value: off, to: today)!
                let o = try ledger.dayOverview(for: d)

                let net = (o.netTotalMain as NSDecimalNumber).doubleValue

                let income = max(net, 0)
                let spend = max(-net, 0)

                let addToday = (income * spendPercent) / Double(days)

                rollover = rollover + addToday - spend

                series.append(rollover)

                lbls.append(off == -1 ? "Yesterday" : (off == 0 ? "Today" : "Tomorrow"))
            }

            if let todayIndex = offsets.firstIndex(of: 0), series.indices.contains(todayIndex) {
                rolloverAllowanceMain = series[todayIndex]
            }
            
            
            dashboard = HomeDashboardData(
                allowedSpendToday: allowedSpendToday,
                savingsBalanceToday: savingsToday,
                allowanceSeries: series,
                allowanceLabels: lbls
            )
        } catch {
            print("HomeView loadDashboardData error:", error)
            dashboard = .empty
        }
    }
}

struct HomeDashboardData: Sendable {
    var allowedSpendToday: Double
    var savingsBalanceToday: Double
    var allowanceSeries: [Double]
    var allowanceLabels: [String]

    static let empty = HomeDashboardData(
        allowedSpendToday: 0,
        savingsBalanceToday: 0,
        allowanceSeries: [0, 0, 0],
        allowanceLabels: ["Yesterday", "Today", "Tomorrow"]
    )
}

struct FlowAreaChart: View {

    let values: [Double]
    let labels: [String]
    let isNegativeTheme: Bool
    let currencyCode: String

    @State private var selectedIndex: Int? = nil
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geo in

            let labelBand: CGFloat = 28
            let chartHeight = max(geo.size.height - labelBand, 1)

            let rawMin = values.min() ?? 0
            let rawMax = values.max() ?? 0

            let anchoredMin = Swift.min(rawMin, 0)
            let anchoredMax = Swift.max(rawMax, 0)

            let baseRange = anchoredMax - anchoredMin
            let pad = max(baseRange * 0.10, 1)

            let minValue = anchoredMin - pad
            let maxValue = anchoredMax + pad
            let range = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue)

            let zeroPosition = CGFloat((0 - minValue) / range)
            let zeroY = chartHeight - (chartHeight * zeroPosition)

            let lineGradient = LinearGradient(
                colors: isNegativeTheme
                ? [
                    Color(red: 1.00, green: 0.35, blue: 0.42),
                    Color(red: 0.85, green: 0.10, blue: 0.25)
                ]
                : [
                    Color(red: 0.35, green: 0.95, blue: 1.00),
                    Color(red: 0.10, green: 0.55, blue: 1.00)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            let fillGradient = LinearGradient(
                colors: isNegativeTheme
                ? [
                    Color(red: 0.95, green: 0.22, blue: 0.30).opacity(0.35),
                    Color(red: 0.95, green: 0.22, blue: 0.30).opacity(0.05)
                ]
                : [
                    Color(red: 0.20, green: 0.70, blue: 1.00).opacity(0.35),
                    Color(red: 0.20, green: 0.70, blue: 1.00).opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            let step = geo.size.width / CGFloat(max(values.count - 1, 1))

            let clamp: (CGFloat, CGFloat, CGFloat) -> CGFloat = { x, mn, mx in
                Swift.max(mn, Swift.min(mx, x))
            }

            let point: (Int) -> CGPoint = { index in
                let x = step * CGFloat(index)
                let pct = CGFloat((values[index] - minValue) / range)
                let y = chartHeight - (chartHeight * pct)
                return CGPoint(x: x, y: y)
            }

            let nearestIndex: (CGFloat) -> Int = { touchX in
                let x = clamp(touchX, 0, geo.size.width)
                let raw = Int(round(x / step))
                return Swift.max(0, Swift.min(values.count - 1, raw))
            }

            ZStack(alignment: .topLeading) {

                Path { path in
                    guard !values.isEmpty else { return }

                    for i in values.indices {
                        let p = point(i)
                        if i == 0 { path.move(to: p) }
                        else { path.addLine(to: p) }
                    }

                    path.addLine(to: CGPoint(x: geo.size.width, y: chartHeight))
                    path.addLine(to: CGPoint(x: 0, y: chartHeight))
                    path.closeSubpath()
                }
                .fill(fillGradient)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: zeroY))
                    path.addLine(to: CGPoint(x: geo.size.width, y: zeroY))
                }
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [6]))

                Path { path in
                    guard !values.isEmpty else { return }

                    for i in values.indices {
                        let p = point(i)
                        if i == 0 { path.move(to: p) }
                        else { path.addLine(to: p) }
                    }
                }
                .stroke(lineGradient, lineWidth: 3)

                ForEach(values.indices, id: \.self) { i in
                    let p = point(i)
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 5, height: 5)
                        .position(p)
                }

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                guard !values.isEmpty else { return }
                                selectedIndex = nearestIndex(value.location.x)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )

                if let i = selectedIndex, values.indices.contains(i) {
                    let p = point(i)

                    Path { path in
                        path.move(to: CGPoint(x: p.x, y: 0))
                        path.addLine(to: CGPoint(x: p.x, y: chartHeight))
                    }
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .position(p)
                        .shadow(radius: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(i < labels.count ? labels[i] : "Day \(i + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.85))

                        Text(values[i].formatted(.currency(code: currencyCode)))
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)

                        Text(values[i] >= 0 ? "Net positive" : "Net negative")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                    .shadow(radius: 10)
                    .position(
                        x: clamp(p.x, 90, geo.size.width - 90),
                        y: max(p.y - 40, 24)
                    )
                    .animation(.easeOut(duration: 0.15), value: selectedIndex)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(0..<values.count, id: \.self) { i in
                            Text(i < labels.count ? labels[i] : "")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white.opacity(0.82))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: labelBand)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
