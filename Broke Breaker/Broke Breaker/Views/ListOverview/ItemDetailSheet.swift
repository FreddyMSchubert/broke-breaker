import SwiftUI
import SwiftData

struct ItemDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: DayLineItem
    let requestDelete: (DayLineItem.Source) -> Void

    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false
    @State private var pendingDelete = false

    // Resolved models
    private var oneTime: OneTimeTransaction? {
        guard case .oneTime(let id) = item.source else { return nil }
        return modelContext.model(for: id) as? OneTimeTransaction
    }

    private var recurring: RecurringRule? {
        guard case .recurring(let id) = item.source else { return nil }
        return modelContext.model(for: id) as? RecurringRule
    }

    private var amountText: String {
        let code = "GBP"
        return (item.amount as NSDecimalNumber).decimalValue.formatted(.currency(code: code))
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 12)
            VStack(spacing: 8) {
                Text(amountText)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(item.amount >= 0 ? .blue : .red)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(item.title)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(2)
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
            Button("Delete", role: .destructive) { requestDelete(item.source) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can’t be undone.")
        }
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

    private func performDeleteNow() {
        guard pendingDelete else { return }
        pendingDelete = false

        let ledger = LedgerService(context: modelContext)

        do {
            switch item.source {
            case .oneTime(let id):
                if let tx = modelContext.model(for: id) as? OneTimeTransaction {
                    try ledger.deleteOneTime(tx)
                }
            case .recurring(let id):
                if let rule = modelContext.model(for: id) as? RecurringRule {
                    try ledger.deleteRecurring(rule)
                }
            }
        } catch {
        }
    }
}

