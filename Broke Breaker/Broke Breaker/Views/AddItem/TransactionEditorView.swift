import SwiftUI
import SharedLedger

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?

    enum FocusedField { case title, amount, every }

    enum Mode: Equatable {
        case create
        case editOneTime(OneTimeTransaction)
        case editRecurring(RecurringRule)

        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.create, .create):
                return true
            case (.editOneTime, .editOneTime):
                return true
            case (.editRecurring, .editRecurring):
                return true
            default:
                return false
            }
        }
    }

    let mode: Mode

    // MARK: - UI State
    @State private var title: String = ""
    @State private var amountDigits: String = ""
    @State private var isPositive: Bool = false
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
        var id: String { "\(self)" }

        var title: String {
            switch self {
            case .error: return "❌ Couldn’t Save"
            case .success: return "✅ Saved"
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

    // MARK: - Init with prefill
    init(mode: Mode) {
        self.mode = mode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(headerTitle)
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

                                TextField("", text: amountDigitsBinding)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .amount)
                                    .foregroundStyle(.clear)
                                    .tint(.clear)
                                    .textSelection(.disabled)
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

                // Date + Type
                HStack(alignment: .center) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(txType == .oneTime ? "Date" : "Start date")
                            .font(.title3.weight(.semibold))

                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Spacer()
                    Spacer()

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
                        .disabled(isEditingLockedType)
                    }

                    Spacer()
                }

                if txType == .repeating {
                    // Schedule
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
                                .tint(primaryActionColor)
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

                // Bottom buttons: Cancel + Save/Create
                HStack(spacing: 12) {
                    if mode != .create {
                        Button(action: { dismiss() }) { Text("Cancel") }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)
                    }

                    Button(action: save) {
                        Text(primaryActionTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(primaryActionColor, in: RoundedRectangle(cornerRadius: 18))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .shadow(radius: 10, y: 6)
                    .opacity(canSave ? 1.0 : 0.5)
                    .disabled(!canSave)
                }

                Spacer(minLength: 10)
            }
            .padding()
        }
        .alert(item: $alert) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                dismissButton: .default(Text("OK"), action: {
                    if case .success = state { dismiss() }
                })
            )
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear { prefillFromMode() }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { focusedField = nil }
        )
    }

    // MARK: - Prefill

    private func prefillFromMode() {
        switch mode {
        case .create:
            break

        case .editOneTime(let tx):
            title = tx.title
            selectedDate = tx.date
            txType = .oneTime
            let amt = tx.amount
            isPositive = (amt >= 0)
            amountDigits = digitsFromDecimal(absDecimal(amt))

        case .editRecurring(let rule):
            title = rule.title
            selectedDate = rule.startDate
            txType = .repeating
            let amt = rule.amountPerCycle
            isPositive = (amt >= 0)
            amountDigits = digitsFromDecimal(absDecimal(amt))

            if let end = rule.endDate {
                hasEndDate = true
                selectedEndDate = end
            } else {
                hasEndDate = false
            }

            switch rule.recurrence {
            case .everyDays(let n):   unit = .days; everyNText = "\(n)"
            case .everyWeeks(let n):  unit = .weeks; everyNText = "\(n)"
            case .everyMonths(let n): unit = .months; everyNText = "\(n)"
            case .everyYears(let n):  unit = .years; everyNText = "\(n)"
            }
        }
    }

    // MARK: - Save/Create

    private func save() {
        guard let magnitude = parsedAmountMagnitude, magnitude > 0 else {
            alert = .error("Enter a valid amount greater than 0.")
            return
        }

        let finalAmount = isPositive ? magnitude : -magnitude
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ledger = Ledger.shared

        do {
            switch mode {
            case .create:
                switch txType {
                case .oneTime:
                    try ledger.addOneTime(title: trimmedTitle, date: selectedDate, amount: finalAmount)
                case .repeating:
                    let recurrence = makeRecurrence()
                    let end: Date? = hasEndDate ? max(selectedEndDate, selectedDate) : nil
                    try ledger.addRecurring(
                        title: trimmedTitle,
                        amountPerCycle: finalAmount,
                        startDate: selectedDate,
                        endDate: end,
                        recurrence: recurrence
                    )
                }
                
                resetInputsForNextCreate();

                alert = .success("Created \(createTransactionName).")

            case .editOneTime(let tx):
                try ledger.updateOneTime(tx, title: trimmedTitle, date: selectedDate, amount: finalAmount)
                alert = .success("Saved \(createTransactionName).")

            case .editRecurring(let rule):
                let recurrence = makeRecurrence()
                let endUpdate: LedgerService.EndDateUpdate = hasEndDate
                    ? .set(max(selectedEndDate, selectedDate))
                    : .clear

                try ledger.updateRecurring(
                    rule,
                    title: trimmedTitle,
                    amountPerCycle: finalAmount,
                    startDate: selectedDate,
                    endDate: endUpdate,
                    recurrence: recurrence
                )
                alert = .success("Saved \(createTransactionName).")
            }
        } catch {
            alert = .error(error.localizedDescription)
        }
    }
    
    private func resetInputsForNextCreate() {
        title = ""
        amountDigits = ""
        isPositive = false
        selectedDate = Date()
        txType = .oneTime

        hasEndDate = false
        selectedEndDate = Date()

        everyNText = "1"
        unit = .days

        focusedField = nil
    }

    private func makeRecurrence() -> Recurrence {
        let n = everyN
        switch unit {
        case .days: return .everyDays(n)
        case .weeks: return .everyWeeks(n)
        case .months: return .everyMonths(n)
        case .years: return .everyYears(n)
        }
    }
    
    private var createTransactionName: String {
        let typeText = (txType == .oneTime) ? "one-time" : "repeating"
        let signText = isPositive ? "income" : "expense"
        return "\(typeText) \(signText)"
    }

    // MARK: - Derived

    private var headerTitle: String {
        switch mode {
        case .create: return "New Transaction"
        case .editOneTime, .editRecurring: return "Edit Transaction"
        }
    }

    private var primaryActionTitle: String {
        switch mode {
        case .create: return "Create \(createTransactionName)"
        case .editOneTime, .editRecurring: return "Save"
        }
    }

    private var primaryActionColor: Color { isPositive ? .blue : .red }

    private var isEditingLockedType: Bool {
        switch mode {
        case .create: return false
        case .editOneTime, .editRecurring: return true
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && amountCents > 0
        && (txType == .oneTime || everyN >= 1)
    }

    private var amountCents: Int { Int(amountDigits) ?? 0 }
    private var parsedAmountMagnitude: Decimal? { Decimal(amountCents) / 100 }

    private var everyN: Int { max(1, Int(everyNText) ?? 1) }

    // MARK: - Input helpers

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

    private var everyBinding: Binding<String> {
        Binding(
            get: { everyNText },
            set: { newValue in
                let digitsOnly = newValue.filter(\.isNumber)
                let trimmed = digitsOnly.drop(while: { $0 == "0" })
                everyNText = trimmed.isEmpty ? (digitsOnly.isEmpty ? "1" : "0") : String(trimmed)
            }
        )
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

    private func signButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? .white : .primary)
        .background(active ? primaryActionColor : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: active ? 0 : 1)
        )
    }

    private func absDecimal(_ d: Decimal) -> Decimal { d < 0 ? -d : d }

    private func digitsFromDecimal(_ value: Decimal) -> String {
        let absValue = value < 0 ? -value : value
        let centsInt = (NSDecimalNumber(decimal: absValue)
            .multiplying(by: NSDecimalNumber(value: 100))).intValue
        return centsInt == 0 ? "" : "\(centsInt)"
    }
}

