import SwiftUI
import SharedLedger

struct ItemDetailSheet: View {
    let ledger = Ledger.shared
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let item: DayLineItem
    let onChanged: () -> Void

    @State private var oneTime: OneTimeTransaction?
    @State private var recurring: RecurringRule?

    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false
    
    @State private var dailyAmount: Decimal
    
    init(day: Date, item: DayLineItem, onChanged: @escaping () -> Void) {
        self.day = day
        self.item = item
        self.onChanged = onChanged
        _dailyAmount = State(initialValue: item.amount)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(format2(displayAmount))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(displayAmount >= 0 ? .blue : .red)

                    if let suffix = headlineSuffix {
                        Text(suffix)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text(displayTitle)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(2)

                if let daily = displayDailyImpact() {
                    Text(daily)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            Form {
                Section("Details") {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(typeLabel)
                            .foregroundStyle(.secondary)
                    }

                    if let tx = oneTime {
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let rule = recurring {
                        HStack {
                            Text("Start date")
                            Spacer()
                            Text(rule.startDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Schedule")
                            Spacer()
                            Text(scheduleLabel(rule.recurrence))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("End date")
                            Spacer()
                            Text(rule.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text("Delete")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    showEditSheet = true
                } label: {
                    Text("Edit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
        .onAppear { reloadModels() }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteNow() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can’t be undone.")
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            reloadModels()
            refreshDailyAmountFromBackend()
            onChanged()
        }) {
            if let tx = oneTime {
                TransactionEditorView(mode: .editOneTime(tx))
                    .presentationDetents([.large])
            } else if let rule = recurring {
                TransactionEditorView(mode: .editRecurring(rule))
                    .presentationDetents([.large])
            } else {
                Text("Missing item.")
                    .presentationDetents([.medium])
            }
        }
    }
    
    private func reloadModels() {
        do {
            switch item.source {
            case .oneTime(let id):
                oneTime = try ledger.fetchOneTime(id: id)
                recurring = nil
            case .recurring(let id):
                recurring = try ledger.fetchRecurring(id: id)
                oneTime = nil
            }
        } catch {
            oneTime = nil
            recurring = nil
        }
    }

    private func deleteNow() {
        do {
            switch item.source {
            case .oneTime(let id):
                if let tx = try ledger.fetchOneTime(id: id) { try ledger.deleteOneTime(tx) }
            case .recurring(let id):
                if let rule = try ledger.fetchRecurring(id: id) { try ledger.deleteRecurring(rule) }
            }
            dismiss()
            onChanged()
        } catch {
            print("Delete failed:", error)
        }
    }

    private var displayAmount: Decimal {
        switch item.source {
        case .oneTime:
            return oneTime?.amount ?? item.amount
        case .recurring:
            return recurring?.amountPerCycle ?? item.amount
        }
    }
    private var displayTitle: String {
        switch item.source {
        case .oneTime: return oneTime?.title ?? item.title
        case .recurring: return recurring?.title ?? item.title
        }
    }
    private func displayDailyImpact() -> String? {
        guard let rule = recurring else { return nil }
        if case .everyDays(1) = rule.recurrence { return nil }
        return "≈ \(format2(dailyAmount)) / day impact"
    }
    
    private func refreshDailyAmountFromBackend() {
        do {
            let overview = try ledger.dayOverview(for: day)

            let updated = overview.items.first { candidate in
                switch (candidate.source, item.source) {
                case (.oneTime(let a), .oneTime(let b)): return a == b
                case (.recurring(let a), .recurring(let b)): return a == b
                default: return false
                }
            }

            if let updated {
                dailyAmount = updated.amount
            }
        } catch {
            // ignore
        }
    }

    private var headlineSuffix: String? {
        guard let rule = recurring else { return nil }
        return "/ " + cycleLabel(rule.recurrence)
    }

    private func cycleLabel(_ r: Recurrence) -> String {
        switch r {
        case .everyDays(let n):   return n == 1 ? "day" : "\(n) days"
        case .everyWeeks(let n):  return n == 1 ? "week" : "\(n) weeks"
        case .everyMonths(let n): return n == 1 ? "month" : "\(n) months"
        case .everyYears(let n):  return n == 1 ? "year" : "\(n) years"
        }
    }

    private func format2(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value)
        return String(format: "%.2f", n.doubleValue)
    }

    private var typeLabel: String {
        switch item.source {
        case .oneTime: return "One-time"
        case .recurring: return "Repeating"
        }
    }

    private func scheduleLabel(_ r: Recurrence) -> String {
        switch r {
        case .everyDays(let n): return "Every \(n) day" + (n == 1 ? "" : "s")
        case .everyWeeks(let n): return "Every \(n) week" + (n == 1 ? "" : "s")
        case .everyMonths(let n): return "Every \(n) month" + (n == 1 ? "" : "s")
        case .everyYears(let n): return "Every \(n) year" + (n == 1 ? "" : "s")
        }
    }
}

