import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(balance: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let balance = UserDefaults(suiteName: "group.com.freddy.brokebreaker")?.double(forKey: "currentBalance") ?? 0
        completion(SimpleEntry(balance: balance))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let balance = UserDefaults(suiteName: "group.com.freddy.brokebreaker")?.double(forKey: "currentBalance") ?? 0
        let entry = SimpleEntry(balance: balance)
        
        // Atualiza à meia-noite
        let calendar = Calendar.current
        let now = Date()
        let nextMidnight = calendar.nextDate(after: now,
                                             matching: DateComponents(hour: 0, minute: 0, second: 0),
                                             matchingPolicy: .nextTime)!
        
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date = Date()
    let balance: Double
}

// MARK: - Widget View
struct BrokeBreakerWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        let isPositive = entry.balance >= 0
        let backgroundColor = isPositive ? Color(red: 0.25, green: 0.45, blue: 0.85) : Color(red: 0.75, green: 0.2, blue: 0.2)

        ZStack {
            backgroundColor
            VStack(spacing: 10) {
                // Emojis
                Text(isPositive ? "💰" : "💸")
                    .font(.system(size: 28))
                    .opacity(0.2)
                
                // Saldo
                Text(formatCurrency(entry.balance))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                // Texto
                Text(isPositive ? "available today" : "over budget!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .containerBackground(for: .widget) { backgroundColor }
    }
    
    // Formata saldo de acordo com currencyCode no UserDefaults
    func formatCurrency(_ amount: Double) -> String {
        let defaults = UserDefaults(suiteName: "group.com.freddy.brokebreaker")
        let currencyCode = defaults?.string(forKey: "currencyCode") ?? "GBP"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Widget
struct BrokeBreakerWidget: Widget {
    let kind: String = "BrokeBreakerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BrokeBreakerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Real Balance")
        .description("Mostra o saldo atualizado da app")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
