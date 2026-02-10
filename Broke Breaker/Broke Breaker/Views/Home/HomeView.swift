

import SwiftUI
import SwiftData


struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    private var ledger: LedgerService { LedgerService(context: modelContext) }

    
    //------Declare Data Variables----------------
    @AppStorage("isDarkMode") private var isDarkMode = false
    // Light/Dark mode storage
    
    //------Declare Data Variables----------------
    
    let dailyBudget: Double = 20
    
    @State private var dailySpendings: [Double] = Array(repeating: 0, count: 7)
    @State private var todaySpending: Double = 0
    // Gets today’s spending amount
    

    let days: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" ]
    
    var body: some View {
        
       
        let dailyDifference = dailyBudget - todaySpending
        // Positive = under budget, Negative = over budget
        
        
        
//---------------------THE SCROLLVIEW-------------------
        
        ZStack{
            (todaySpending <= dailyBudget ? Color.blue.opacity(0.45)
             : Color(.sRGB, red: 0.45, green: 0.0, blue: 0.0, opacity: 1.0))//burgundy red
            .ignoresSafeArea()
            
            
            
            
            ScrollView {     // Allows scrolling if screen content becomes too tall
                VStack(spacing: 30) {
                    
                    
                    
//---------------------- PAGE TITLE--------------------
                    
                    Text("Spending Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
//--------------TODAY SUMMARY CARD------------------
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Spending")
                            .font(.headline)
                        
                        Text("£\(todaySpending, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .bold))
                        
                        // Green if under budget, red if over budget
                            .foregroundColor(todaySpending <= dailyBudget ? .green : .red)
                        
                        
                        Text(todaySpending <= dailyBudget
                             ? "You're within budget today ✅"
                             : "You've exceeded today's budget ")
                        
                    }//END
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    
                    
//------------------- DAILY BUDGET DIFFERENCE CARD ------------------------
                    VStack(alignment: .leading, spacing: 12) {
                        
                        Text("Today's Budget Performance")
                            .font(.headline)
// -------------------------------------------------
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Budget")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("£\(dailyBudget, specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }//End
                            
                            
                            Spacer()
                            
// -------------------------------------------------
                            VStack(alignment: .leading) {
                                Text("Spent")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("£\(todaySpending, specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }//End
                            
                            
                            Spacer()
// ----------------------------------------------------
                            
                            VStack(alignment: .leading) {
                                Text("Difference")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("£\(abs(dailyDifference), specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(dailyDifference >= 0 ? .green : .red)
                                
                            }//END
                        }
                        
// -------------------------------------------------
                        Text(dailyDifference >= 0
                             ? "Great discipline! Save today and spend tomorrow wisely 🌱"
                             : "Please stick to budget — the future rewards discipline. Let’s work together, friend 💪")
                        .font(.subheadline)
                        .foregroundColor(dailyDifference >= 0 ? .green : .red)
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    
                    
//                    
//// -------------- WEEKLY FLOW CHART SECTION---------------
//                    HStack{
//                        ForEach(days.indices, id:\.self) {index in
//                            VStack(spacing: 6) {
//                                Text(days[index])
//                                    .font(.caption)
//                                    .foregroundColor(.black)
//                                    .fontWeight(.bold)
//                                
//                                Text("£\(dailySpendings[index], specifier: "%.0f")")
//                                    .font(.subheadline)
//                                    .fontWeight(.bold)
//                                
//                            }
//                            .frame(maxWidth: .infinity)
//                        }
//                    }//END
                    
// -------------------------------------------------
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Spending Trend")
                            .font(.headline)
                        FlowAreaChart(values: dailySpendings, budget: dailyBudget)
                            .frame(height: 200) // Fixed height so chart looks balanced
                        
                    }
                    
                    Spacer()  // Push everything upward for clean spacing
                    
                }
                .padding() // Adds space from screen edges
                
                
            }//Close ScrollView
            
            
        }//Close ZStack
        .task { loadRealData() }
        
    }//close var body
    private func loadRealData() {
        do {
            
            let totalsToday = try ledger.dayTotals(for: Date())
            todaySpending = (totalsToday.netTotal as NSDecimalNumber).doubleValue

    //------ Last 7 days totals (oldest - newest)------
            var values: [Double] = []
            let cal = Calendar.current

            for offset in stride(from: 6, through: 0, by: -1) {
                let date = cal.date(byAdding: .day, value: -offset, to: Date())!
                let totals = try ledger.dayTotals(for: date)
                values.append((totals.netTotal as NSDecimalNumber).doubleValue)
            }

            dailySpendings = values
        } catch {
            print("HomeView loadRealData error:", error)
            todaySpending = 0
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
