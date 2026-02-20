import Foundation
import SharedLedger

let dbPath = "./ledger.sqlite"

do {
	let ledger = try LedgerService(databasePath: dbPath)

	_ = try ledger.addOneTime(title: "Coffee", date: Date(), amount: Decimal(string: "-3.50")!)
	_ = try ledger.addRecurring(
		title: "Salary",
		amountPerCycle: Decimal(string: "2000")!,
		startDate: Calendar.current.startOfDay(for: Date()),
		endDate: nil,
		recurrence: .everyMonths(1)
	)

	let overview = try ledger.dayOverview(for: Date())
	print("Day start:", overview.dayStart)
	for item in overview.items {
		print("-", item.title, item.amount)
	}
	print("Net:", overview.netTotal)

	let totals = try ledger.dayTotals(for: Date())
	print("Running EOD:", totals.runningBalanceEndOfDay)

} catch {
	print("Error:", error)
	exit(1)
}
