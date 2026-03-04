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
	//testing searchTransactions
	do {
    // Create an in-memory database for testing purposes (use a file for production)
    let db = try Connection(.inMemory)

    // Define the table and columns
    let transactions = Table("transactions")
    let id = Expression<Int64>("id")
    let title = Expression<String>("title")
    let amount = Expression<Decimal>("amount")
    let count = Expression<Int64>("count")

    // Create the table (if it doesn't exist)
    try db.run(transactions.create(ifNotExists: true) { t in
        t.column(id, primaryKey: true)
        t.column(title)
        t.column(amount)
        t.column(count)
    })

    // Insert sample data
    try db.run(transactions.insert(title <- "Coffee", amount <- 3.5, count <- 5))
    try db.run(transactions.insert(title <- "Groceries", amount <- 25.0, count <- 10))
    try db.run(transactions.insert(title <- "Book", amount <- 12.99, count <- 3))
    try db.run(transactions.insert(title <- "Coffee Beans", amount <- 8.75, count <- 8))

    // Now you can call searchTransactions to test
    let results = try searchTransactions("coffee", db: db)

    // Print the results to verify sorting
    for transaction in results {
        print("Found transaction: \(transaction.title), Amount: \(transaction.amount), Count: \(transaction.count)")
    }

} catch {
    print("Error:", error)
} 	//end of testing searchTransactionsw
