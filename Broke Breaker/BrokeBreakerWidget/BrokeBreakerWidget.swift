//
//  BrokeBreakerWidget.swift
//  BrokeBreakerWidget
//
//  Created by кαяєи ʝαи∂ιяα💖 on 10/02/2026.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct BrokeBreakerWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        let balance: Decimal = 15.50
        let isPositive = balance >= 0
        
        let backgroundColor = isPositive
        ? Color(red: 0.25, green: 0.45, blue: 0.85)
        : Color(red: 0.75, green: 0.2, blue: 0.2)
        
        ZStack {
            
            // Emojis desorganizados (background)
            // Emojis desorganizados (background)
            ZStack {
                
                Text(isPositive ? "💰" : "💸")
                    .font(.system(size: 22))
                    .opacity(0.18)
                    .blur(radius: 1.2)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -70, y: -60)
                
                Text(isPositive ? "😊" : "😢")
                    .font(.system(size: 20))
                    .opacity(0.16)
                    .blur(radius: 1)
                    .rotationEffect(.degrees(12))
                    .offset(x: -20, y: -55)
                
                Text(isPositive ? "💵" : "📉")
                    .font(.system(size: 24))
                    .opacity(0.18)
                    .blur(radius: 1.3)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 55, y: -45)
                
                Text(isPositive ? "🤑" : "😰")
                    .font(.system(size: 21))
                    .opacity(0.16)
                    .blur(radius: 1)
                    .rotationEffect(.degrees(20))
                    .offset(x: 70, y: -10)
                
                Text(isPositive ? "💰" : "💸")
                    .font(.system(size: 19))
                    .opacity(0.15)
                    .blur(radius: 1)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -55, y: 10)
                
                Text(isPositive ? "💵" : "📉")
                    .font(.system(size: 23))
                    .opacity(0.18)
                    .blur(radius: 1.2)
                    .rotationEffect(.degrees(15))
                    .offset(x: 10, y: 35)
                
                Text(isPositive ? "😊" : "😢")
                    .font(.system(size: 20))
                    .opacity(0.15)
                    .blur(radius: 1)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -35, y: 55)
                
                Text(isPositive ? "🤑" : "😰")
                    .font(.system(size: 22))
                    .opacity(0.17)
                    .blur(radius: 1.1)
                    .rotationEffect(.degrees(9))
                    .offset(x: 60, y: 50)
            }
            // Conteúdo principal
            VStack(spacing: 8) {
                
                Text("£\(NSDecimalNumber(decimal: balance).stringValue)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
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


struct BrokeBreakerWidget: Widget {
    let kind: String = "BrokeBreakerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            BrokeBreakerWidgetEntryView(entry: entry)
                
        }
    }
}
extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    BrokeBreakerWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley)
    SimpleEntry(date: .now, configuration: .starEyes)
}
