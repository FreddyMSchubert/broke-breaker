import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: FocusedField?

    enum FocusedField {
        case title, amount, every
    }

    // MARK: - UI State
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var isPositive: Bool = false
    @State private var selectedDate: Date = Date()

    enum TxType: String, CaseIterable, Identifiable {
        case oneTime = "One-time"
        case repeating = "Repeating"
        var id: String { rawValue }
    }
    @State private var txType: TxType = .oneTime

    enum RecurrenceUnitUI: CaseIterable, Identifiable {
        case days, weeks, months, years
        var id: String { "\(self)" }

        func label(for n: Int) -> String {
            let singular = (n == 1)
            switch self {
                case .days:   return singular ? "Day" : "Days"
                case .weeks:  return singular ? "Week" : "Weeks"
                case .months: return singular ? "Month" : "Months"
                case .years:  return singular ? "Year" : "Years"
            }
        }
    }

    @State private var everyNText: String = "1"
    @State private var unit: RecurrenceUnitUI = .days

    // Feedback
    @State private var errorMessage: String?
    @State private var didCreateFlash: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.title3.weight(.semibold))

                    TextField("e.g. Rent, Salary, Coffee, Groceries…", text: $title)
                        .font(.system(size: 18, weight: .medium))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .title)
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Amount
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.title3.weight(.semibold))

                    HStack(spacing: 12) {
                        VStack(spacing: 10) {
                            signButton(label: "+", active: isPositive) { isPositive = true }
                            signButton(label: "–", active: !isPositive) { isPositive = false }
                        }
                        .frame(width: 56)

                        VStack(alignment: .leading, spacing: 6) {
                            TextField("0", text: amountBinding)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .amount)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text(isPositive ? "Income (positive)" : "Expense (negative)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                HStack(alignment: .center) {
                    Spacer()
                    // Date / Start date (always present)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(txType == .oneTime ? "Date" : "Start date")
                            .font(.title3.weight(.semibold))

                        DatePicker(
                            "",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Spacer()
                    Spacer()
                    // Type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.title3.weight(.semibold))

                        Picker("Type", selection: $txType) {
                            ForEach(TxType.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Spacer()
                }

                // Repeating controls
                if txType == .repeating {
                    HStack {
                        Spacer()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Schedule")
                                .font(.title3.weight(.semibold))

                            HStack(spacing: 10) {
                                Text("Every")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                TextField("1", text: everyBinding)
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .every)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .frame(width: 56)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Picker("Unit", selection: $unit) {
                                    ForEach(RecurrenceUnitUI.allCases) { u in
                                        Text(u.label(for: everyN)).tag(u)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                } else if didCreateFlash {
                    Text("Created ✅")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                Button(action: create) {
                    Text(createButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(createButtonColor)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 10, y: 6)
                .opacity(canCreate ? 1.0 : 0.5)
                .disabled(!canCreate)

                Spacer(minLength: 10)
            }
            .padding()
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: txType)
        }
        .navigationTitle("New Transaction")
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Bindings that sanitize input

    /// Decimal input that rejects letters and keeps only one decimal separator.
    private var amountBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { newValue in
                amountText = sanitizeDecimal(newValue)
            }
        )
    }

    /// Integer input for recurrence (no letters, no decimals, never empty).
    private var everyBinding: Binding<String> {
        Binding(
            get: { everyNText },
            set: { newValue in
                let cleaned = sanitizeInt(newValue)
                everyNText = cleaned.isEmpty ? "1" : cleaned
            }
        )
    }

    private func sanitizeDecimal(_ raw: String) -> String {
        // Allow digits + one "." (we’ll normalize commas to ".")
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        var out = ""
        var dotUsed = false

        for ch in normalized {
            if ch.isNumber {
                out.append(ch)
            } else if ch == "." && !dotUsed {
                dotUsed = true
                out.append(ch)
            } else {
                // ignore everything else (letters, currency, spaces, etc.)
            }
        }

        // avoid leading "." -> "0."
        if out == "." { out = "0." }

        return out
    }

    private func sanitizeInt(_ raw: String) -> String {
        let digitsOnly = raw.filter { $0.isNumber }
        // trim leading zeros but keep at least one digit
        let trimmed = digitsOnly.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? (digitsOnly.isEmpty ? "" : "0") : String(trimmed)
    }

    // MARK: - UI Helpers

    private func signButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? .white : .primary)
        .background(active ? createButtonColor : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: active ? 0 : 1)
        )
    }
    
    private var createButtonTitle: String {
        let typeText = (txType == .oneTime) ? "one-time" : "repeating"
        let signText = isPositive ? "income" : "expense"
        return "Create \(typeText) \(signText)"
    }

    private var createButtonColor: Color { isPositive ? .blue : .red }

    private var everyN: Int {
        max(1, Int(everyNText) ?? 1)
    }

    private var parsedAmountMagnitude: Decimal? {
        let cleaned = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: cleaned)
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (parsedAmountMagnitude ?? 0) > 0
        && (txType == .oneTime || everyN >= 1)
    }

    // MARK: - Create

    private func create() {
        errorMessage = nil
        didCreateFlash = false

        guard let magnitude = parsedAmountMagnitude, magnitude > 0 else {
            errorMessage = "Enter a valid amount greater than 0."
            return
        }

        let finalAmount = isPositive ? magnitude : -magnitude
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ledger = LedgerService(context: modelContext)

        do {
            switch txType {
            case .oneTime:
                try ledger.addOneTime(title: trimmedTitle, date: selectedDate, amount: finalAmount)

            case .repeating:
                let recurrence: Recurrence = {
                    let n = everyN
                    switch unit {
                    case .days: return .everyDays(n)
                    case .weeks: return .everyWeeks(n)
                    case .months: return .everyMonths(n)
                    case .years: return .everyYears(n)
                    }
                }()

                try ledger.addRecurring(
                    title: trimmedTitle,
                    amountPerCycle: finalAmount,
                    startDate: selectedDate,
                    endDate: nil,
                    recurrence: recurrence
                )
            }

            // Reset
            title = ""
            amountText = ""
            isPositive = false
            selectedDate = Date()
            everyNText = "1"
            unit = .days
            txType = .oneTime

            didCreateFlash = true
            focusedField = nil
        } catch {
            errorMessage = "Could not create transaction: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack { AddItemView() }
        .modelContainer(for: [OneTimeTransaction.self, RecurringRule.self, DailyCacheEntry.self], inMemory: true)
}
