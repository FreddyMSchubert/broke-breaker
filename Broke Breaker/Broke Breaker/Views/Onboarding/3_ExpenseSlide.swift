import SwiftUI

struct ExpenseSlideView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("Then, log expenses")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Like incomes, expenses can be recurring, such as subscriptions, or one-time, such as groceries.")
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            VStack(spacing: 18) {
                HStack {
                    Text("One-time")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("Recurring")
                        .font(.system(size: 16, weight: .semibold))
                }

                Image("expense_graphic")
                    .resizable()
                    .scaledToFill()

                HStack {
                    Spacer()
                    Text("...")
                    Spacer()
                    Text("Ystd.")
                    Spacer()
                    Text("Today")
                    Spacer()
                    Text("Tmrw.")
                    Spacer()
                    Text("...")
                    Spacer()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Text("One-time transactions are taken from the balance of each day.")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)

                Text("Recurring transaction money is taken equally from each day of the recurring cycle, clarifying the impact it has on each individual day. This makes the cost more intuitive to grasp.")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.vertical, 32)
    }
}
