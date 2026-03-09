import Foundation
import SharedLedger

let dbPath = "./ledger.sqlite"

do {
	let ledger = try LedgerService(databasePath: dbPath)

	_ = try ledger.addOneTime(title: "Coffee", date: Date(), amount: Decimal(string: "-3.50")!)
	_ = try ledger.addOneTime(title: "Coffin", date: Date(), amount: Decimal(string: "-300.50")!)
	_ = try ledger.addOneTime(title: "Coffin", date: Date(), amount: Decimal(string: "-300.50")!)
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
		print("-", item.title, item.mainAmount, item.savingsAmount)
	}
	print("Net:", overview.netTotalMain, overview.netTotalSavings)

	let totals = try ledger.dayTotals(for: Date())
	print("Running EOD:", totals.runningBalanceMainEndOfDay, totals.runningBalanceSavingsEndOfDay)

	let results = try ledger.searchTransactions("coff", type: TransactionSource.oneTime(id: 0))

	print(results)
} catch {
	print("Error:", error)
	exit(1)
}
