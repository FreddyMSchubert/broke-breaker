//
//  widgetdatahelper.swift
//  Broke Breaker
//
//  Created by кαяєи ʝαи∂ιяα💖 on 12/03/2026.
//

import Foundation
import WidgetKit

struct WidgetDataHelper {
    static let suiteName = "group.com.freddy.brokebreaker"
    
    
    static func updateWidgetData(balance: Double) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        
        // current balance
        defaults.set(balance, forKey: "currentBalance")
        
        // historic
        var history = getBalanceHistory()
        
        // add today
        let today = Calendar.current.startOfDay(for: Date())
        history[today] = balance
        
        // 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        history = history.filter { $0.key >= sevenDaysAgo }
        
        // store
        saveBalanceHistory(history)
        
        // widget update
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // history
    static func getBalanceHistory() -> [Date: Double] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "balanceHistory"),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        
        // Converte strings de volta para Date
        var result: [Date: Double] = [:]
        let formatter = ISO8601DateFormatter()
        for (key, value) in decoded {
            if let date = formatter.date(from: key) {
                result[date] = value
            }
        }
        return result
    }
    
    // Save history
    private static func saveBalanceHistory(_ history: [Date: Double]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        
        // Converte Date para String (JSON não aceita Date direto)
        let formatter = ISO8601DateFormatter()
        var encoded: [String: Double] = [:]
        for (date, value) in history {
            encoded[formatter.string(from: date)] = value
        }
        
        if let data = try? JSONEncoder().encode(encoded) {
            defaults.set(data, forKey: "balanceHistory")
        }
    }
}
