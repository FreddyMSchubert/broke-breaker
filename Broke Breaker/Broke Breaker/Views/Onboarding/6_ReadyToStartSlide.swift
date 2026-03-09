import SwiftUI

struct ReadyToStartSlideView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("You're ready to get started.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Please remember:")
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 18) {
                reminderRow(
                    number: "1.",
                    text: "Log all of your incomes and expenses, whether they are one-time or repeating."
                )

                reminderRow(
                    number: "2.",
                    text: "Watch the number. It's just a few digits, but they'll change your life."
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 24)

            Text("Good luck!")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Spacer()
        }
        .padding(.vertical, 32)
    }

    private func reminderRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 18, weight: .bold))

            Text(text)
                .font(.system(size: 17, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
