import SwiftUI
import SwiftData


struct HomeView: View {
    
    @Environment(\.modelContext) private var modelContext
    private var ledger: LedgerService { LedgerService(context: modelContext) }

    
    //------Declare Data Variables----------------
    @AppStorage("isDarkMode") private var isDarkMode = false
   
    
    //------Declare Data Variables----------------
    @State private var showTodayDetails = false

    @State private var balanceToday: Double = 0
    @State private var netToday: Double = 0
    @State private var dailySpendings: [Double] = Array(repeating: 0, count: 7)
    
    private var isNegativeToday: Bool { netToday < 0 }

    

    
    
    var body: some View {
        ZStack{
            (isNegativeToday
             ? Color(.sRGB, red: 0.78, green: 0.29, blue: 0.29, opacity: 1.0)
             : Color.blue.opacity(0.45))

            .ignoresSafeArea()
           
            
//---------------------THE SCROLLVIEW-------------------
            ScrollView {
                VStack(spacing: 30) {
                    
                    
                    
//---------------------- PAGE TITLE--------------------
                    
                    Text("Spending Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    
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
                        FlowAreaChart(values: dailySpendings, budget: 0)
                            .frame(height: 200)
                        
                    }
                    
                    Spacer()
                    
                }
                .padding()
                .foregroundColor(isNegativeToday ? .white : .primary)

                
                
            }//Close ScrollView
            
            
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
            print("netToday =", netToday)


            var values: [Double] = []

            for offset in stride(from: 6, through: 0, by: -1) {
                let date = cal.date(byAdding: .day, value: -offset, to: today)!
                let totals = try ledger.dayTotals(for: date)
                values.append((totals.netTotal as NSDecimalNumber).doubleValue)
            }

            dailySpendings = values

        } catch {
            print("HomeView loadRealData error:", error)
            balanceToday = 0
            netToday = 0
            dailySpendings = Array(repeating: 0, count: 7)
        }
    }


    
    
}//Close HomeView
    

// -------------------------------------------------

#Preview {
    let schema = Schema([
        OneTimeTransaction.self,
        RecurringRule.self,
        DailyCacheEntry.self
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    return HomeView()
        .modelContainer(container)
}

// -------------------------------------------------




// -------------------FLOW CHART---------------------------
struct FlowAreaChart: View {
   
    let values: [Double]
    let budget: Double
    
    var body: some View {
        
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 1, budget) // Finds the highest value between spending and budget
            
            
//---------------FILLED SPENDING AREA---------------------

            ZStack {
                
                Path { path in
                    
                    for index in values.indices { // Loops through every day’s spending value
                        
                        // Spreads points evenly across the width of the chart
                        let x = geo.size.width / CGFloat(values.count - 1) * CGFloat(index)
                        
                        // Converts spending amount into vertical screen position
                        // Bigger spending = higher point on chart
                        let y = geo.size.height - (geo.size.height * CGFloat(values[index] / maxValue))
                       
                        if index == 0 {
                            // Starts the drawing path at the first data point
                            path.move(to: CGPoint(x: x, y: y))
                            
                        } else {
                            // Draws straight lines connecting points
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    // Drop line down to bottom-right corner
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    
                    // Draws line to bottom-left corner
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    
                    // Closes shape so it can be filled
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .blue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
// ----------------SPENDING LINE-------------------------
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
            }
        }
    }
}
