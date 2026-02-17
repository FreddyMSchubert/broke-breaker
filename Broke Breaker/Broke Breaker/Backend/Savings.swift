import Vapor
import Fluent

final class SavingsAccount: Model, Content {
    static let schema = "savings_accounts"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "balance")
    var balance: Double

    @Field(key: "goal")
    var goal: Double

    init() {}

    init(balance: Double = amount, goal: Double = amount) {
        self.balance = balance
        self.goal = goal
    }
}

final class DailyAllowance: Model, Content {
    static let schema = "daily_allowances"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "amount")
    var amount: Double

    @Field(key: "spentToday")
    var spentToday: Double

    init() {}

    init(amount: Double, spentToday: Double = 0) {
        self.amount = amount
        self.spentToday = spentToday
    }
}

struct CreateSavingsAccount: Migration {
    func prepare(on db: Database) -> EventLoopFuture<Void> {
        db.schema("savings_accounts")
            .id()
            .field("balance", .double, .required)
            .field("goal", .double, .required)
            .create()
    }

    func revert(on db: Database) -> EventLoopFuture<Void> {
        db.schema("savings_accounts").delete()
    }
}

struct CreateDailyAllowance: Migration {
    func prepare(on db: Database) -> EventLoopFuture<Void> {
        db.schema("daily_allowances")
            .id()
            .field("amount", .double, .required)
            .field("spentToday", .double, .required)
            .create()
    }

    func revert(on db: Database) -> EventLoopFuture<Void> {
        db.schema("daily_allowances").delete()
    }
}

struct SavingsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let savings = routes.grouped("savings")

        savings.post("setGoal", use: setGoal)
        savings.post("setDailyAllowance", use: setDailyAllowance)
        savings.post("addSpending", use: addSpending)
        savings.post("endOfDay", use: endOfDay)

        savings.get("balance", use: getBalance)
        savings.get("progress", use: getProgress)
    }

    // POST /savings/setGoal { "goal": 500 }
    func setGoal(req: Request) throws -> EventLoopFuture<SavingsAccount> {
        struct Input: Content { let goal: Double }
        let input = try req.content.decode(Input.self)

        return SavingsAccount.query(on: req.db).first().flatMap { existing in
            let account = existing ?? SavingsAccount()
            account.goal = input.goal
            return account.save(on: req.db).map { account }
        }
    }

    // POST /savings/setDailyAllowance { "amount": 20 }
    func setDailyAllowance(req: Request) throws -> EventLoopFuture<DailyAllowance> {
        struct Input: Content { let amount: Double }
        let input = try req.content.decode(Input.self)

        return DailyAllowance.query(on: req.db).first().flatMap { existing in
            let allowance = existing ?? DailyAllowance(amount: input.amount)
            allowance.amount = input.amount
            return allowance.save(on: req.db).map { allowance }
        }
    }

    // POST /savings/addSpending { "amount": 5 }
    func addSpending(req: Request) throws -> EventLoopFuture<DailyAllowance> {
        struct Input: Content { let amount: Double }
        let input = try req.content.decode(Input.self)

        return DailyAllowance.query(on: req.db).first().unwrap(or: Abort(.notFound)).flatMap { allowance in
            allowance.spentToday += input.amount
            return allowance.save(on: req.db).map { allowance }
        }
    }

    // POST /savings/endOfDay
    // leftover = allowance.amount - allowance.spentToday
    // savings.balance += leftover, spentToday reset to 0
    func endOfDay(req: Request) throws -> EventLoopFuture<SavingsAccount> {
        return DailyAllowance.query(on: req.db).first().unwrap(or: Abort(.notFound)).flatMap { allowance in
            let leftover = max(allowance.amount - allowance.spentToday, 0)

            return SavingsAccount.query(on: req.db).first().flatMap { existing in
                let account = existing ?? SavingsAccount()
                account.balance += leftover

                allowance.spentToday = 0

                return account.save(on: req.db).and(allowance.save(on: req.db)).map { _ in account }
            }
        }
    }

    // GET /savings/balance
    func getBalance(req: Request) throws -> EventLoopFuture<Double> {
        SavingsAccount.query(on: req.db).first().map { $0?.balance ?? 0 }
    }

    // GET /savings/progress
    func getProgress(req: Request) throws -> EventLoopFuture<Double> {
        SavingsAccount.query(on: req.db).first().map { account in
            guard let account = account, account.goal > 0 else { return 0 }
            return account.balance / account.goal
        }
    }
}
