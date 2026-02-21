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
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct BrokeBreakerWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        let defaults = UserDefaults(suiteName: "group.com.freddy.brokebreaker")
        let balance = defaults?.double(forKey: "currentBalance") ?? 0
        let isPositive = balance >= 0
        
        let backgroundColor = isPositive
        ? Color(red: 0.25, green: 0.45, blue: 0.85)
        : Color(red: 0.75, green: 0.2, blue: 0.2)
        
        ZStack {
            
            // Background emojis
            ZStack {
                
                Text(isPositive ? "💰" : "💸")
                    .font(.system(size: 24))
                    .opacity(0.30)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -70, y: -60)
                
                Text(isPositive ? "😊" : "😢")
                    .font(.system(size: 22))
                    .opacity(0.28)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(12))
                    .offset(x: -20, y: -55)
                
                Text(isPositive ? "💵" : "📉")
                    .font(.system(size: 26))
                    .opacity(0.30)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 55, y: -45)
                
                Text(isPositive ? "🤑" : "😰")
                    .font(.system(size: 23))
                    .opacity(0.28)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(20))
                    .offset(x: 70, y: -10)
                
                Text(isPositive ? "💰" : "💸")
                    .font(.system(size: 21))
                    .opacity(0.26)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -55, y: 10)
                
                Text(isPositive ? "💵" : "📉")
                    .font(.system(size: 25))
                    .opacity(0.30)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(15))
                    .offset(x: 10, y: 35)
                
                Text(isPositive ? "😊" : "😢")
                    .font(.system(size: 22))
                    .opacity(0.26)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -35, y: 55)
                
                Text(isPositive ? "🤑" : "😰")
                    .font(.system(size: 24))
                    .opacity(0.28)
                    .blur(radius: 0.6)
                    .rotationEffect(.degrees(9))
                    .offset(x: 60, y: 50)
        }
            
            // Main content
            VStack(spacing: 8) {
                
                Text("£\(balance, specifier: "%.2f")")
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
