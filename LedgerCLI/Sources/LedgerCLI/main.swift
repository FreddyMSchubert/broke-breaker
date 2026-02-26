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
	_ = try ledger.addOneTime(title: "Mum's gift", date: Date(), amount: Decimal(string: "-40")!)
	_ = try ledger.addSavingsTransfer(
		title: "Transfer to Savings",
		date: Date(),
		amount: Decimal(string: "25")!
	)
	_ = try ledger.addOneTime(title: "Savings", 
		date: Date(), 
		amount: Decimal(string: "1.25")!, 
		isSavings: true)
	_ = try ledger.addOneTime(title: "For savings transfer", 
		date: Date(), 
		amount: Decimal(string: "100")!, 
		isSavings: true
	)
	_ = try ledger.addOneTime(title: "Dad's gift", 
		date: Date(), 
		amount: Decimal(string: "50")!, 
		isSavings: false
	)
	_ = try ledger.addOneTime(title: "Dinner", 
		date: Date(), 
		amount: Decimal(string: "25")!, 
		isSavings: false
	)
	_ = try ledger.addOneTime(title: "Emergency fund transfer", 
		date: Date(), 
		amount: Decimal(string: "25")!, 
		isSavings: true
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
