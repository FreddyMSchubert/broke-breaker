import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date = Date()
    let balance: Double
    let history: [Date: Double]  // new
}

// MARK: - Timeline Provider (update)
struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(balance: 0, history: [:])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let balance = UserDefaults(suiteName: "group.com.freddy.brokebreaker")?.double(forKey: "currentBalance") ?? 0
        let history = WidgetDataHelper.getBalanceHistory()
        completion(SimpleEntry(balance: balance, history: history))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let balance = UserDefaults(suiteName: "group.com.freddy.brokebreaker")?.double(forKey: "currentBalance") ?? 0
        let history = WidgetDataHelper.getBalanceHistory()
        let entry = SimpleEntry(balance: balance, history: history)
        
        // Update midnight
        let calendar = Calendar.current
        let now = Date()
        let nextMidnight = calendar.nextDate(after: now,
                                             matching: DateComponents(hour: 0, minute: 0, second: 0),
                                             matchingPolicy: .nextTime)!
        
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

// MARK: - Widget View with EMOJIS
struct BrokeBreakerWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        let isPositive = entry.balance >= 0
        let backgroundColor = isPositive
            ? Color(red: 0.055, green: 0.155, blue: 0.37)
            : Color(red: 0.37, green: 0.06, blue: 0.12)

        GeometryReader { geo in
            ZStack {
                // Background emojis
                let width = geo.size.width
                let height = geo.size.height
                
                // Top row
                Text(isPositive ? "💰" : "💸")
                    .font(.system(size: 22))
                    .opacity(0.35)
                    .rotationEffect(.degrees(-18))
                    .position(x: width * 0.15, y: height * 0.2)
                
                Text(isPositive ? "😊" : "😢")
                    .font(.system(size: 20))
                    .opacity(0.3)
                    .rotationEffect(.degrees(12))
                    .position(x: width * 0.85, y: height * 0.15)
                
                // Middle row
                Text(isPositive ? "💵" : "📉")
                    .font(.system(size: 24))
                    .opacity(0.35)
                    .rotationEffect(.degrees(-10))
                    .position(x: width * 0.2, y: height * 0.5)
                
                Text(isPositive ? "🤑" : "😰")
                    .font(.system(size: 21))
                    .opacity(0.3)
                    .rotationEffect(.degrees(20))
                    .position(x: width * 0.8, y: height * 0.45)
                
                // Bottom row
                Text(isPositive ? "💰" : "💸")
                    .font(.system(size: 19))
                    .opacity(0.28)
                    .rotationEffect(.degrees(-8))
                    .position(x: width * 0.12, y: height * 0.8)
                
                Text(isPositive ? "💵" : "📉")
                    .font(.system(size: 23))
                    .opacity(0.35)
                    .rotationEffect(.degrees(15))
                    .position(x: width * 0.88, y: height * 0.85)
                
                Text(isPositive ? "😊" : "😢")
                    .font(.system(size: 20))
                    .opacity(0.28)
                    .rotationEffect(.degrees(-22))
                    .position(x: width * 0.5, y: height * 0.2)
                
                Text(isPositive ? "🤑" : "😰")
                    .font(.system(size: 22))
                    .opacity(0.32)
                    .rotationEffect(.degrees(9))
                    .position(x: width * 0.5, y: height * 0.8)
                
                // Main content
                VStack(spacing: 8) {
                    Text(formatCurrency(entry.balance))
                        .font(.system(size: min(width * 0.18, 36), weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                    
                    Text(isPositive ? "available today" : "over budget!")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .containerBackground(for: .widget) {
                backgroundColor
            }
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let defaults = UserDefaults(suiteName: "group.com.freddy.brokebreaker")
        let currencyCode = defaults?.string(forKey: "currencyCode") ?? "GBP"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Widget View graph
struct BrokeBreakerChartWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        let isPositive = entry.balance >= 0
        let backgroundColor = isPositive
            ? Color(red: 0.055, green: 0.155, blue: 0.37)
            : Color(red: 0.37, green: 0.06, blue: 0.12)
        
        GeometryReader { geo in
            VStack(spacing: 12) {
                // main balance
                VStack(spacing: 4) {
                    Text(formatCurrency(entry.balance))
                        .font(.system(size: min(geo.size.width * 0.15, 32), weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(isPositive ? "available today" : "over budget!")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Mini graph
                MiniChart(history: entry.history, currentBalance: entry.balance, isPositive: isPositive)
                    .frame(height: geo.size.height * 0.4)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .containerBackground(for: .widget) {
                backgroundColor
            }
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let defaults = UserDefaults(suiteName: "group.com.freddy.brokebreaker")
        let currencyCode = defaults?.string(forKey: "currencyCode") ?? "GBP"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Mini Chart Component
struct MiniChart: View {
    let history: [Date: Double]
    let currentBalance: Double
    let isPositive: Bool
    
    private var chartData: (values: [Double], hasData: Bool) {
        let sorted = history.sorted { $0.key < $1.key }
        let values = sorted.map { $0.value }
        return (values, values.count >= 2)
    }
    
    var body: some View {
        GeometryReader { geo in
            let data = chartData
            
            if !data.hasData {
                // Not enough data
                Text("Not enough data")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let values = data.values
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 0
                let range = maxVal - minVal
                let safeRange = range == 0 ? 1 : range
                
                let lineColor = isPositive
                    ? Color(red: 0.35, green: 0.95, blue: 1.0)
                    : Color(red: 1.0, green: 0.35, blue: 0.42)
                
                let fillGradient = LinearGradient(
                    colors: [lineColor.opacity(0.4), lineColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                ZStack {
                    // area
                    Path { path in
                        let stepX = geo.size.width / CGFloat(values.count - 1)
                        
                        for (index, value) in values.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalized = CGFloat((value - minVal) / safeRange)
                            let y = geo.size.height - (geo.size.height * normalized)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        
                        // closing
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(fillGradient)
                    
                    // graph line
                    Path { path in
                        let stepX = geo.size.width / CGFloat(values.count - 1)
                        
                        for (index, value) in values.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalized = CGFloat((value - minVal) / safeRange)
                            let y = geo.size.height - (geo.size.height * normalized)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(lineColor, lineWidth: 2.5)
                    
                    // current point 
                    if let lastValue = values.last {
                        let x = geo.size.width
                        let normalized = CGFloat((lastValue - minVal) / safeRange)
                        let y = geo.size.height - (geo.size.height * normalized)
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}
    // MARK: - Widgets
    struct BrokeBreakerWidget: Widget {
        let kind: String = "BrokeBreakerWidget"
        
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: Provider()) { entry in
                BrokeBreakerWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Balance with Emojis")
            .description("Shows your balance with fun emojis")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        }
    }
    
    struct BrokeBreakerChartWidget: Widget {
        let kind: String = "BrokeBreakerChartWidget"
        
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: Provider()) { entry in
                BrokeBreakerChartWidgetView(entry: entry)
            }
            .configurationDisplayName("Balance with Chart")
            .description("Shows your balance with a trend chart")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        }
    }
