import SwiftUI
import SharedLedger

struct HomeView: View {
    
    let ledger = Ledger.shared
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("selectedCurrencyCode") private var currencySelected = "GBP"
    
    @State private var settingsActive = false
    
    @State private var balanceToday: Double = 0
    @State private var savingsToday: Double = 0
    
    @State private var values: [Double] = Array(repeating: 0, count: 3)
    @State private var labels: [String] = []
    
   
    @State private var glassShine: CGFloat = -200
    @State private var shineTimer: Timer?
    
    private var isNegativeToday: Bool { balanceToday < 0 }
    
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
                    
                    ZStack(alignment: .bottomTrailing) {
                        
                        VStack(alignment: .leading, spacing: 14) {
                            
                            Text("Disposable Today")
                                .font(.subheadline)
                                .opacity(0.85)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)\(balanceToday, specifier: "%.2f")")
                                .font(.system(size: 40, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Divider().opacity(0)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 26)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.18),
                                            Color.white.opacity(0.06),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.55),
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        
                        //-------------------------------------------------------------------
                        .overlay(
                            GeometryReader { geo in
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(width: geo.size.width * 0.6)
                                .rotationEffect(.degrees(18))
                                .offset(x: glassShine)
                                .blur(radius: 6)
                                .blendMode(.screen)
                            }
                                .clipShape(RoundedRectangle(cornerRadius: 26))
                        )
                        .shadow(color: .white.opacity(0.05), radius: 6, x: 0, y: -2)
                        .shadow(color: .black.opacity(0.30), radius: 24, x: 0, y: 14)
                        
                        
                        //---------------------------------------------------------------------
                        
                        VStack(spacing: 4) {
                            Text("Savings")
                                .font(.caption)
                                .opacity(0.75)
                            
                            Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)\(savingsToday, specifier: "%.2f")")
                                .font(.headline.weight(.bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                        )
                        
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.18),
                                            Color.white.opacity(0.06),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                        .offset(x: 12, y: 14)
                        
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        
                        FlowAreaChart(
                            values: values,
                            labels: labels,
                            isNegativeTheme: isNegativeToday,
                            currencyCode: currencySelected
                        )
                        .frame(height: 320)
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
                            radius: 20,
                            x: 0,
                            y: 10
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
        .onAppear {
            startGlassShine()
            
            shineTimer?.invalidate()
            
            shineTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                startGlassShine()
            }
        }
        
        .onDisappear {
            shineTimer?.invalidate()
            shineTimer = nil
        }
    }
    
    func startGlassShine() {
        glassShine = -300
        
        withAnimation(.easeInOut(duration: 6)) {
            glassShine = 500
        }
    }

    
    private func loadRealData() {
        do {
            let cal = Calendar.current
            let today = Date()
            
            let totalsToday = try ledger.dayTotals(for: today)
            balanceToday = (totalsToday.runningBalanceMainEndOfDay as NSDecimalNumber).doubleValue
            savingsToday = (totalsToday.runningBalanceSavingsEndOfDay as NSDecimalNumber).doubleValue
            
            let offsets = [-1, 0, 1]
            var tempValues: [Double] = []
            var tempLabels: [String] = []
            
            for off in offsets {
                let date = cal.date(byAdding: .day, value: off, to: today)!
                let totals = try ledger.dayTotals(for: date)
                
                tempValues.append((totals.runningBalanceMainEndOfDay as NSDecimalNumber).doubleValue)
                
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
            values = Array(repeating: 0, count: 3)
            labels = ["Yesterday", "Today", "Tomorrow"]
        }
    }
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
            
            let yAxisLabels = values.map {
                $0.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
            }
            
            let labelBand: CGFloat = 30
            let topPadding: CGFloat = 16
            let bottomPadding: CGFloat = 12
            
            let longestLabelCount = yAxisLabels.map { $0.count }.max() ?? 0
            let estimatedPadding = CGFloat(longestLabelCount) * 6
            let leftPadding = min(max(52, estimatedPadding), 64)
            
            let chartHeight = max(geo.size.height - labelBand, 1)
            let plotHeight = max(chartHeight - topPadding - bottomPadding, 1)
            
            let minValue = min(values.min() ?? 0, 0)
            let maxValue = max(values.max() ?? 0, 0)
            let range = (maxValue - minValue == 0) ? 1 : (maxValue - minValue)
            
            let step = (geo.size.width - leftPadding) / CGFloat(max(values.count - 1, 1))
            
            let yPosition: (Double) -> CGFloat = { value in
                topPadding + CGFloat((maxValue - value) / range) * plotHeight
            }
            
            let boundaryY = yPosition(0)
            
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
            
            let clamp: (CGFloat, CGFloat, CGFloat) -> CGFloat = { x, mn, mx in
                Swift.max(mn, Swift.min(mx, x))
            }
            
            let point: (Int) -> CGPoint = { index in
                let x = leftPadding + step * CGFloat(index)
                let y = yPosition(values[index])
                return CGPoint(x: x, y: y)
            }
            
            let nearestIndex: (CGFloat) -> Int = { touchX in
                let x = clamp(touchX - leftPadding, 0, geo.size.width - leftPadding)
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
                    path.addLine(to: CGPoint(x: leftPadding, y: chartHeight))
                    path.closeSubpath()
                }
                .fill(fillGradient)
                
                Path { path in
                    path.move(to: CGPoint(x: leftPadding, y: topPadding))
                    path.addLine(to: CGPoint(x: leftPadding, y: topPadding + plotHeight))
                }
                .stroke(Color.white.opacity(0.30), lineWidth: 2)
                
                Path { path in
                    path.move(to: CGPoint(x: leftPadding, y: boundaryY))
                    path.addLine(to: CGPoint(x: geo.size.width, y: boundaryY))
                }
                .stroke(Color.white.opacity(0.18), lineWidth: 1.8)
                
                Path { path in
                    guard !values.isEmpty else { return }
                    
                    for i in values.indices {
                        let p = point(i)
                        if i == 0 { path.move(to: p) }
                        else { path.addLine(to: p) }
                    }
                }
                .stroke(lineGradient, lineWidth: 2)
                
                ForEach(values.indices, id: \.self) { i in
                    let p = point(i)
                    
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 5, height: 5)
                        .position(p)
                }
                
                ForEach(0..<values.count, id: \.self) { i in
                    let label = yAxisLabels[i]
                    
                    let parts: (String, String) = {
                        if let firstComma = label.firstIndex(of: ","),
                           let secondComma = label[label.index(after: firstComma)...].firstIndex(of: ",") {
                            
                            let splitIndex = label.index(after: secondComma)
                            
                            return (
                                String(label[..<splitIndex]),
                                String(label[splitIndex...])
                            )
                        } else {
                            return (label, "")
                        }
                    }()
                    
                    let labelYOffset: CGFloat = parts.1.isEmpty ? 0 : 6
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(parts.0)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        if !parts.1.isEmpty {
                            Text(parts.1)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.78))
                    .frame(width: leftPadding - 6, alignment: .trailing)
                    .position(
                        x: (leftPadding / 2) + 2,
                        y: min(yPosition(values[i]) + labelYOffset, chartHeight - 18)
                    )
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
                        path.move(to: CGPoint(x: p.x, y: topPadding))
                        path.addLine(to: CGPoint(x: p.x, y: topPadding + plotHeight))
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
                            .foregroundStyle(.white.opacity(0.82))
                        
                        Text(values[i].formatted(.currency(code: currencyCode)))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text(values[i] >= 0 ? "Net positive" : "Net negative")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minWidth: 120, alignment: .leading)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
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
