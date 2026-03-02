import SwiftUI
import SharedLedger

struct HomeView: View {
    
    let ledger = Ledger.shared
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var settingsActive = false
    
    @State private var balanceToday: Double = 0
    @State private var netToday: Double = 0
    
    @State private var values: [Double] = Array(repeating: 0, count: 3)
    @State private var labels: [String] = []
    
    private var isNegativeToday: Bool { netToday < 0 }
    
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

                        Text("Disposable Today")
                            .font(.subheadline)
                            .opacity(0.85)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("\(balanceToday, specifier: "%.2f")")
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
                            values: values,
                            labels: labels,
                            isNegativeTheme: isNegativeToday
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
                        .shadow(color: isNegativeToday ? .red.opacity(0.28) : .blue.opacity(0.28),
                                radius: 20, x: 0, y: 10)
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
            }
            .buttonStyle(.plain)
            .glassEffect()
            .padding(.top, 10)
            .padding(.trailing, 14)
            .sheet(isPresented: $settingsActive) {
                SettingsView()
            }
        }
        .task { loadRealData() }
    }
    
    private func loadRealData() {
        do {
            let cal = Calendar.current
            let today = Date()
            
            let totalsToday = try ledger.dayTotals(for: today)
            netToday = (totalsToday.netTotal as NSDecimalNumber).doubleValue
            balanceToday = (totalsToday.runningBalanceEndOfDay as NSDecimalNumber).doubleValue
            
            let offsets = [-1, 0, 1]
            
            var tempValues: [Double] = []
            var tempLabels: [String] = []
            
            for off in offsets {
                let date = cal.date(byAdding: .day, value: off, to: today)!
                let totals = try ledger.dayTotals(for: date)
                
                tempValues.append((totals.runningBalanceEndOfDay as NSDecimalNumber).doubleValue)
                
                if off == -1 {
                    tempLabels.append("Yesterday")
                } else if off == 0 {
                    tempLabels.append("Today")
                } else {
                    tempLabels.append("Tomorrow")
                }
            }
            
            values = tempValues
            labels = tempLabels
            
        } catch {
            print("HomeView loadRealData error:", error)
            balanceToday = 0
            netToday = 0
            values = Array(repeating: 0, count: 3)
            labels = ["Yesterday", "Today", "Tomorrow"]
        }
    }
}

struct FlowAreaChart: View {
    
    let values: [Double]
    let labels: [String]
    let isNegativeTheme: Bool
    
    var body: some View {
        GeometryReader { geo in
            
            let labelBand: CGFloat = 28
            let chartHeight = max(geo.size.height - labelBand, 1)
            
            let minValue = min(values.min() ?? 0, 0)
            let maxValue = max(values.max() ?? 0, 0)
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
            
            ZStack(alignment: .topLeading) {
                
                Path { path in
                    for i in values.indices {
                        let x = step * CGFloat(i)
                        let pct = CGFloat((values[i] - minValue) / range)
                        let y = chartHeight - (chartHeight * pct)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
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
                    for i in values.indices {
                        let x = step * CGFloat(i)
                        let pct = CGFloat((values[i] - minValue) / range)
                        let y = chartHeight - (chartHeight * pct)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(lineGradient, lineWidth: 3)
                
                ForEach(values.indices, id: \.self) { i in
                    let x = step * CGFloat(i)
                    let pct = CGFloat((values[i] - minValue) / range)
                    let y = chartHeight - (chartHeight * pct)
                    
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 7, height: 7)
                        .position(x: x, y: y)
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
