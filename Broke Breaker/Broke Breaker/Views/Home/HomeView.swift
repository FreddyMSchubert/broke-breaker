import SwiftUI
import SharedLedger


struct HomeView: View {
    
    let ledger = Ledger.shared

    //------Declare Data Variables----------------
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var settingsActive = false
    
    //------Declare Data Variables----------------
    @State private var showTodayDetails = false

    @State private var balanceToday: Double = 0
    @State private var netToday: Double = 0
    @State private var dailySpendings: [Double] = Array(repeating: 0, count: 7)
    
    @State private var selectedIndex: Int? = nil
    @State private var selectedDayItems: [DayLineItem] = []
    @State private var selectedDayNet: Double = 0
    @State private var selectedDayDate: Date = Date()
    
    @State private var showChartFullScreen = false
    
    @Namespace private var chartNamespace
    
    private var isNegativeToday: Bool { netToday < 0 }

    var body: some View {
        HStack {
            Spacer()
            Button(action: { settingsActive = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
            }
            .buttonStyle(.plain)
            .glassEffect()
            .sheet(isPresented: $settingsActive) {
                SettingsView()
            }
        }
        .padding([.top, .horizontal])
        
        ZStack{
            
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
           
            
//---------------------THE SCROLLVIEW-------------------
            ScrollView {
                VStack(spacing: 30) {
                    
                    
                    
//---------------------- PAGE TITLE--------------------
                    
                    Text("BROKE BREAK")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(1)
                    
    //--------------TODAY SUMMARY CARD------------------
                    ZStack {

                        if !showTodayDetails {
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    showTodayDetails.toggle()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 14) {

                                    HStack {
                                        Text("Today")
                                            .font(.headline)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.headline)
                                            .opacity(0.8)
                                    }

                                    Text("Balance")
                                        .font(.subheadline)
                                        .opacity(0.85)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    Text("£\(balanceToday, specifier: "%.2f")")
                                        .font(.system(size: 40, weight: .bold))
                                        .frame(maxWidth: .infinity, alignment: .center)

                                }//END
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .cornerRadius(20)
                                .shadow(radius: 6)
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                    removal: .move(edge: .trailing).combined(with: .opacity)))
                        }

                        if showTodayDetails {
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    showTodayDetails.toggle()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 14) {

                                    HStack {
                                        Text("Today Details")
                                            .font(.headline)

                                        Spacer()

                                        Image(systemName: "chevron.left")
                                            .font(.headline)
                                            .opacity(0.8)
                                    }

                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Net Today")
                                                .font(.caption)
                                                .opacity(0.8)

                                            Text("£\(netToday, specifier: "%.2f")")
                                                .font(.title2.weight(.bold))
                                        }

                                        Spacer()
                                    }

                                    Divider().opacity(0.25)

                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Balance End Of Day")
                                                .font(.caption)
                                                .opacity(0.8)

                                            Text("£\(balanceToday, specifier: "%.2f")")
                                                .font(.title3.weight(.semibold))
                                        }

                                        Spacer()
                                    }

                                }//END
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.thinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .cornerRadius(20)
                                .shadow(radius: 10)
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                        }

                    }

                    
// -------------------------------------------------
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Net Trend")
                            .font(.headline)
                        
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                                showChartFullScreen = true
                            }
                        } label: {
                            VStack(spacing: 12) {
                                FlowAreaChart(values: dailySpendings, budget: 0, selectedIndex: $selectedIndex, isNegativeTheme: isNegativeToday)
                                    .frame(height: 200)
                                    .onChange(of: selectedIndex) { newValue in
                                        guard let newValue else { return }
                                        updateSelectedDayDetails(index: newValue)
                                    }
                                
                                if selectedIndex != nil {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(selectedDayDate.formatted(date: .abbreviated, time: .omitted))
                                                .font(.subheadline.weight(.semibold))
                                            
                                            Spacer()
                                            
                                            Text("£\(selectedDayNet, specifier: "%.2f")")
                                                .font(.subheadline.weight(.bold))
                                        }
                                        
                                        if selectedDayItems.isEmpty {
                                            Text("No transactions")
                                                .font(.caption)
                                                .opacity(0.7)
                                        } else {
                                            ForEach(selectedDayItems) { item in
                                                HStack {
                                                    Text(item.title)
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                    
                                                    Spacer()
                                                    
                                                    Text("£\(NSDecimalNumber(decimal: item.amount).doubleValue, specifier: "%.2f")")
                                                        .font(.caption.weight(.semibold))
                                                }
                                                .opacity(0.95)
                                            }
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                    .cornerRadius(18)
                                    .transition(.opacity)
                                }
                            }
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
                            .shadow(color: isNegativeToday ? .red.opacity(0.28) : .blue.opacity(0.28), radius: 20, x: 0, y: 10)
                            .matchedGeometryEffect(id: "chartCard", in: chartNamespace)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                }
                .padding()
                .foregroundColor(.white)

                
                
            }//Close ScrollView
            
            
            if showChartFullScreen {
                ChartFullScreenOverlay(
                    values: dailySpendings,
                    selectedIndex: $selectedIndex,
                    selectedDayItems: $selectedDayItems,
                    selectedDayNet: $selectedDayNet,
                    selectedDayDate: $selectedDayDate,
                    ledger: ledger,
                    isNegativeTheme: isNegativeToday,
                    onClose: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                            showChartFullScreen = false
                        }
                    }
                )
                .matchedGeometryEffect(id: "chartCard", in: chartNamespace)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
            
            
        }//Close ZStack
        .task { loadRealData() }
        
    }//close var body
    
    
private func loadRealData() {
        do {
            let cal = Calendar.current
            let today = Date()

            let totalsToday = try ledger.dayTotals(for: today)
            netToday = (totalsToday.netTotal as NSDecimalNumber).doubleValue
            balanceToday = (totalsToday.runningBalanceEndOfDay as NSDecimalNumber).doubleValue


            var values: [Double] = []

            for offset in stride(from: 6, through: 0, by: -1) {
                let date = cal.date(byAdding: .day, value: -offset, to: today)!
                let totals = try ledger.dayTotals(for: date)
                values.append((totals.netTotal as NSDecimalNumber).doubleValue)
            }

            dailySpendings = values
            selectedIndex = nil
            selectedDayItems = []
            selectedDayNet = 0
            selectedDayDate = today

        } catch {
            print("HomeView loadRealData error:", error)
            balanceToday = 0
            netToday = 0
            dailySpendings = Array(repeating: 0, count: 7)
            selectedIndex = nil
            selectedDayItems = []
            selectedDayNet = 0
            selectedDayDate = Date()
        }
    }

    
private func updateSelectedDayDetails(index: Int) {
        let cal = Calendar.current
        let today = Date()
        let offset = 6 - index
        let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
        selectedDayDate = date
        
        do {
            let overview = try ledger.dayOverview(for: date)
            selectedDayItems = overview.items
            selectedDayNet = (overview.netTotal as NSDecimalNumber).doubleValue
        } catch {
            selectedDayItems = []
            selectedDayNet = 0
        }
    }


    
    
}//Close HomeView
    


struct ChartFullScreenOverlay: View {
    
    let values: [Double]
    
    @Binding var selectedIndex: Int?
    @Binding var selectedDayItems: [DayLineItem]
    @Binding var selectedDayNet: Double
    @Binding var selectedDayDate: Date
    
    let ledger: LedgerService
    let isNegativeTheme: Bool
    let onClose: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            VStack(spacing: 14) {
                
                HStack {
                    Text("Daily Net Trend")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .opacity(0.85)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 14)
                
                FlowAreaChart(values: values, budget: 0, selectedIndex: $selectedIndex, isNegativeTheme: isNegativeTheme)
                    .frame(height: 340)
                    .padding(.horizontal)
                    .onChange(of: selectedIndex) { newValue in
                        guard let newValue else { return }
                        updateSelectedDayDetails(index: newValue)
                    }
                
                if selectedIndex != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(selectedDayDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            
                            Spacer()
                            
                            Text("£\(selectedDayNet, specifier: "%.2f")")
                                .font(.subheadline.weight(.bold))
                        }
                        
                        if selectedDayItems.isEmpty {
                            Text("No transactions")
                                .font(.caption)
                                .opacity(0.7)
                        } else {
                            ForEach(selectedDayItems) { item in
                                HStack {
                                    Text(item.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("£\(NSDecimalNumber(decimal: item.amount).doubleValue, specifier: "%.2f")")
                                        .font(.caption.weight(.semibold))
                                }
                                .opacity(0.95)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .cornerRadius(18)
                    .padding(.horizontal)
                } else {
                    Text("Swipe across the chart to inspect days")
                        .font(.caption)
                        .opacity(0.75)
                        .padding(.bottom, 10)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.86),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(28)
            .shadow(color: isNegativeTheme ? .red.opacity(0.25) : .blue.opacity(0.25), radius: 28, x: 0, y: 18)
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if g.translation.height > 0 {
                            dragOffset = g.translation.height
                        }
                    }
                    .onEnded { g in
                        if g.translation.height > 140 {
                            onClose()
                        }
                        dragOffset = 0
                    }
            )
            .padding(.top, 20)
            .padding(.bottom, 20)
            .padding(.horizontal, 12)
        }
    }
    
    
    private func updateSelectedDayDetails(index: Int) {
        let cal = Calendar.current
        let today = Date()
        let offset = 6 - index
        let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
        selectedDayDate = date
        
        do {
            let overview = try ledger.dayOverview(for: date)
            selectedDayItems = overview.items
            selectedDayNet = (overview.netTotal as NSDecimalNumber).doubleValue
        } catch {
            selectedDayItems = []
            selectedDayNet = 0
        }
    }
}


// -------------------------------------------------

#Preview {
    // create preview db
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("preview-ledger.sqlite")
    // clean old preview db if it exists
    try? FileManager.default.removeItem(at: tmp)

    let ledger = Ledger.shared

    return HomeView()
}

// -------------------------------------------------




// -------------------FLOW CHART---------------------------
struct FlowAreaChart: View {
   
    let values: [Double]
    let budget: Double
    @Binding var selectedIndex: Int?
    let isNegativeTheme: Bool
    
    var body: some View {
        
        GeometryReader { geo in
            let minValue = min(values.min() ?? 0, 0)
            let maxValue = max(values.max() ?? 0, 0)
            let range = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue)
            
            let zeroPosition = CGFloat((0 - minValue) / range)
            let zeroY = geo.size.height - (geo.size.height * zeroPosition)
            
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
            
            ZStack {
                
                Path { path in
                    for index in values.indices {
                        let x = geo.size.width / CGFloat(max(values.count - 1, 1)) * CGFloat(index)
                        let percentage = CGFloat((values[index] - minValue) / range)
                        let y = geo.size.height - (geo.size.height * percentage)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(fillGradient)
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: zeroY))
                    path.addLine(to: CGPoint(x: geo.size.width, y: zeroY))
                }
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [6]))
                
                Path { path in
                    for index in values.indices {
                        let x = geo.size.width / CGFloat(max(values.count - 1, 1)) * CGFloat(index)
                        let percentage = CGFloat((values[index] - minValue) / range)
                        let y = geo.size.height - (geo.size.height * percentage)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineGradient, lineWidth: 3)
                
                if let i = selectedIndex, values.indices.contains(i) {
                    let x = geo.size.width / CGFloat(max(values.count - 1, 1)) * CGFloat(i)
                    let percentage = CGFloat((values[i] - minValue) / range)
                    let y = geo.size.height - (geo.size.height * percentage)
                    
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)
                        .shadow(color: .white.opacity(0.25), radius: 10, x: 0, y: 0)
                }
                
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                let step = geo.size.width / CGFloat(max(values.count - 1, 1))
                                let raw = Int(round(g.location.x / step))
                                let clamped = min(max(raw, 0), max(values.count - 1, 0))
                                selectedIndex = values.isEmpty ? nil : clamped
                            }
                            .onEnded { _ in
                                if values.isEmpty {
                                    selectedIndex = nil
                                }
                            }
                    )
            }
        }
    }
}

