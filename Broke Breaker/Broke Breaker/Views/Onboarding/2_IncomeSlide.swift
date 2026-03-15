import SwiftUI

struct IncomeSlideView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Text("Here's how it works")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Input all your incomes into Broke Breaker, whether they are recurring or one-time.")
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Income")
                        .font(.system(size: 22, weight: .semibold))

                    Text("e.g. Salary, Freelance, Pocket Money, etc.")
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                Image("income_graphic")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 24)

            Text("That allows Broke Breaker to calculate how much you can spend each day without running out near the end of the month.")
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.vertical, 32)
    }
}
