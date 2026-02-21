import SwiftUI
import SharedLedger

struct ItemDetailSheet: View {
    let ledger = Ledger.shared
    @Environment(\.dismiss) private var dismiss

    let item: DayLineItem
    let requestDelete: (DayLineItem.Source) -> Void

    let oneTime: OneTimeTransaction?
    let recurring: RecurringRule?

    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

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

                Text(item.title)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(2)

                if let daily = approxDailyImpactText() {
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
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            // Keep your existing behavior: caller controls deletion
            Button("Delete", role: .destructive) { requestDelete(item.source) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can’t be undone.")
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

    private func approxDailyImpactText() -> String? {
        guard let rule = recurring else { return nil }
        if case .everyDays(1) = rule.recurrence { return nil }
        return "≈ \(format2(item.amount)) / day impact"
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

