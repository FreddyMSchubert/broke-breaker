import SwiftUI
import SharedLedger

struct AddItemView: View {
    let ledger = Ledger.shared
    @FocusState private var focusedField: FocusedField?

    enum FocusedField {
        case title, amount, every
    }

    // MARK: - UI State
    @State private var title: String = ""
    @State private var amountDigits: String = ""
    @State private var isPositive: Bool = false
    @State private var bypassBudgetWarningOnce = false
    @State private var selectedDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var selectedEndDate: Date = Date()

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
        case budgetWarning(projectedBalance: Decimal, availableBudget: Decimal)

        var id: String {
            switch self {
            case .error(let msg): return "error:\(msg)"
            case .success(let msg): return "success:\(msg)"
            case .budgetWarning(let projectedBalance, let availableBudget):
                return "budgetWarning:\(projectedBalance)-\(availableBudget)"
            }
        }

        var title: String {
            switch self {
            case .error: return "❌ Couldn’t Create Transaction"
            case .success: return "✅ Transaction logged."
            case .budgetWarning: return "⚠️ Over Budget"
            }
        }

        var message: String {
            switch self {
            case .error(let msg): return msg
            case .success(let msg): return msg
            case .budgetWarning(let projectedBalance, let availableBudget):
                let shortfall = max(Decimal(0), -projectedBalance)
                return "This expense would exceed the available balance for that day (\(AddItemView.formatNumber(availableBudget))) by \(AddItemView.formatNumber(shortfall)). Add it anyway?"
            }
        }
    }

    @State private var alert: AlertState?

    // MARK: - Budget warning support

    private struct PendingTransaction {
        let title: String
        let date: Date
        let amount: Decimal
        let txType: TxType
        let recurrence: Recurrence?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("New Transaction")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                
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
                            ZStack(alignment: .leading) {
                                HStack(spacing: 0) {
                                    Text(formattedUKFromDigits(amountDigits))
                                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                    
                                    if focusedField == .amount {
                                        FakeCaret(height: 28)
                                    }
                                }
                                .padding(.horizontal, 14)
                                
                                // Invisible editor
                                TextField("", text: amountDigitsBinding)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .amount)
                                    .foregroundStyle(.clear) // hide digits
                                    .tint(.clear) // hide caret
                                    .textSelection(.disabled) // hide selection
                                    .padding(.horizontal, 14)
                            }
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
                        .tint(.primary)
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
                                .tint(.primary)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    // End date
                    HStack {
                        Spacer()

                        VStack(alignment: .leading, spacing: 10) {

                            HStack(spacing: 10) {
                                Text("End date")
                                    .font(.title3.weight(.semibold))

                                Toggle("", isOn: Binding(
                                    get: { hasEndDate },
                                    set: { on in
                                        hasEndDate = on
                                        if on { selectedEndDate = max(selectedEndDate, selectedDate) }
                                    }
                                ))
                                .labelsHidden()
                                .tint(createButtonColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                            }

                            if hasEndDate {
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { max(selectedEndDate, selectedDate) },
                                        set: { selectedEndDate = max($0, selectedDate) }
                                    ),
                                    in: selectedDate...,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Spacer()
                    }
                }
                
                Button(action: { create() }) {
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
        .onTapGesture { focusedField = nil }
        .alert(item: $alert) { state in
            switch state {
            case .budgetWarning:
                return Alert(
                    title: Text(state.title),
                    message: Text(state.message),
                    primaryButton: .destructive(Text("Add anyway")) {
                        bypassBudgetWarningOnce = true
                        create()
                        bypassBudgetWarningOnce = false
                    },
                    secondaryButton: .cancel()
                )
                
            default:
                return Alert(
                    title: Text(state.title),
                    message: Text(state.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Commit / Reset / Budget helpers

    private func commit(_ tx: PendingTransaction) {
        let ledger = LedgerService(context: modelContext)

        do {
            switch tx.txType {
            case .oneTime:
                try ledger.addOneTime(title: tx.title, date: tx.date, amount: tx.amount)

            case .repeating:
                guard let recurrence = tx.recurrence else {
                    alert = .error("Invalid recurrence settings.")
                    return
                }

                try ledger.addRecurring(
                    title: tx.title,
                    amountPerCycle: tx.amount,
                    startDate: tx.date,
                    endDate: nil,
                    recurrence: recurrence
                )
            }

            alert = .success(createTransactionName.capitalized + " saved.")
            resetForm()

        } catch {
            alert = .error("Could not create transaction: \(error.localizedDescription)")
        }
    }

    private func resetForm() {
        title = ""
        amountDigits = ""
        isPositive = false
        selectedDate = Date()
        everyNText = "1"
        unit = .days
        txType = .oneTime
        focusedField = nil
    }

    private func spendingTotal(for date: Date) throws -> Decimal {
        let ledger = LedgerService(context: modelContext)
        let overview = try ledger.dayOverview(for: date)

        // Expenses only (negative amounts), converted to positive "spend"
        return overview.items.reduce(Decimal(0)) { partial, item in
            item.amount < 0 ? partial + (-item.amount) : partial
        }
    }
    
    private func availableBudget(on date: Date) throws -> Decimal {
        let ledger = LedgerService(context: modelContext)
        return try ledger.balanceEndOfDay(on: date)
    }
    // MARK: - Input sanitization

    private var amountCents: Int {
        Int(amountDigits) ?? 0
    }

    private var parsedAmountMagnitude: Decimal? {
        Decimal(amountCents) / 100
    }

    private var amountDigitsBinding: Binding<String> {
        Binding(
            get: { amountDigits },
            set: { newValue in
                let digitsOnly = newValue.filter(\.isNumber)
                let capped = String(digitsOnly.prefix(12))

                let trimmed = capped.drop(while: { $0 == "0" })
                amountDigits = trimmed.isEmpty ? (capped.isEmpty ? "" : "0") : String(trimmed)
            }
        )
    }

    private static func formatNumber(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "0.00"
    }


    private func formattedUKFromDigits(_ digits: String) -> String {
        let cents = Int(digits) ?? 0
        let pounds = Decimal(cents) / 100

        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "en_GB")
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2

        return nf.string(from: pounds as NSDecimalNumber) ?? "0.00"
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

    private func create(forceSave: Bool = false) {
        guard let magnitude = parsedAmountMagnitude, magnitude > 0 else {
            alert = .error("Enter a valid amount greater than 0.")
            return
        }

        let finalAmount = isPositive ? magnitude : -magnitude
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let recurrence: Recurrence? = {
            guard txType == .repeating else { return nil }
            let n = everyN
            switch unit {
            case .days: return .everyDays(n)
            case .weeks: return .everyWeeks(n)
            case .months: return .everyMonths(n)
            case .years: return .everyYears(n)
            }
        }()

        let tx = PendingTransaction(
            title: trimmedTitle,
            date: selectedDate,
            amount: finalAmount,
            txType: txType,
            recurrence: recurrence
        )

        // Budget warning for ONE-TIME EXPENSES on the SELECTED day (not just today)
        if !forceSave, txType == .oneTime, !isPositive {
            do {
                let available = try availableBudget(on: selectedDate)
                let projectedBalance = available - magnitude  // magnitude is positive, expense reduces balance

                if projectedBalance < 0 {
                    alert = .budgetWarning(projectedBalance: projectedBalance, availableBudget: available)
                    return
                }
            } catch {
                // if calc fails, don't block creation
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

                let end: Date? = hasEndDate ? max(selectedEndDate, selectedDate) : nil

                try ledger.addRecurring(
                    title: trimmedTitle,
                    amountPerCycle: finalAmount,
                    startDate: selectedDate,
                    endDate: end,
                    recurrence: recurrence
                )
            }
            alert = .success(createTransactionName.capitalized + " saved.")

            // Reset (unchanged)
            title = ""
            amountDigits = ""
            isPositive = false
            selectedDate = Date()
            hasEndDate = false
            selectedEndDate = Date()
            everyNText = "1"
            unit = .days
            txType = .oneTime
            focusedField = nil

        } catch {
            alert = .error("Could not create transaction: \(error.localizedDescription)")
        }

        commit(tx)
    }
}

#Preview {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("preview-ledger.sqlite")
    try? FileManager.default.removeItem(at: tmp)

    let ledger = Ledger.shared

    return RootTabView()
}
