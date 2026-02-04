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
    @State private var amountDigits: String = ""
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

    // MARK: - Alerts
    private enum AlertState: Identifiable {
        case error(String)
        case success(String)

        var id: String {
            switch self {
            case .error(let msg): return "error:\(msg)"
            case .success(let msg): return "success:\(msg)"
            }
        }

        var title: String {
            switch self {
            case .error: return "❌ Couldn’t Create Transaction"
            case .success: return "✅ Transaction logged."
            }
        }

        var message: String {
            switch self {
            case .error(let msg): return msg
            case .success(let msg): return msg
            }
        }
    }

    @State private var alert: AlertState?

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
                            TextField("0", text: amountCentsBinding)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .keyboardType(.numberPad)
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

                    // Date Picker
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

                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        .alert(item: $alert) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Input sanitization

    private var amountCents: Int {
        Int(amountDigits) ?? 0
    }

    private var parsedAmountMagnitude: Decimal? {
        Decimal(amountCents) / 100
    }

    private var amountCentsBinding: Binding<String> {
        Binding(
            get: { formatCents(amountCents) },
            set: { newValue in
                let digitsOnly = newValue.filter { $0.isNumber }
                let capped = String(digitsOnly.prefix(12))

                let trimmed = capped.drop(while: { $0 == "0" })
                amountDigits = trimmed.isEmpty ? (capped.isEmpty ? "" : "0") : String(trimmed)
            }
        )
    }

    private func formatCents(_ cents: Int) -> String {
        let absCents = abs(cents)
        let major = absCents / 100
        let minor = absCents % 100
        return "\(major),\(String(format: "%02d", minor))"
    }

    private var everyBinding: Binding<String> {
        Binding(
            get: { everyNText },
            set: { newValue in
                let cleaned = sanitizeInt(newValue)
                everyNText = cleaned.isEmpty ? "1" : cleaned
            }
        )
    }

    private func sanitizeInt(_ raw: String) -> String {
        let digitsOnly = raw.filter { $0.isNumber }
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

    private var createTransactionName: String {
        let typeText = (txType == .oneTime) ? "one-time" : "repeating"
        let signText = isPositive ? "income" : "expense"
        return "\(typeText) \(signText)"
    }
    private var createButtonTitle: String {
        return "Create \(createTransactionName)"
    }

    private var createButtonColor: Color { isPositive ? .blue : .red }

    private var everyN: Int {
        max(1, Int(everyNText) ?? 1)
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && amountCents > 0
        && (txType == .oneTime || everyN >= 1)
    }

    // MARK: - Create

    private func create() {
        guard let magnitude = parsedAmountMagnitude, magnitude > 0 else {
            alert = .error("Enter a valid amount greater than 0.")
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
            
            // success feedback
            alert = .success(createTransactionName.capitalized + " saved.")

            // Reset
            title = ""
            amountDigits = ""
            isPositive = false
            selectedDate = Date()
            everyNText = "1"
            unit = .days
            txType = .oneTime
            focusedField = nil

        } catch {
            alert = .error("Could not create transaction: \(error.localizedDescription)")
        }
    }
}

#Preview {
    RootTabView()
}

