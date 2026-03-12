import SwiftUI

struct WelcomeSlideView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("Welcome to")
                    .font(.system(size: 21, weight: .medium))
                Text("Broke Breaker")
                    .font(.system(size: 42, weight: .bold, design: .rounded))

                Text("Together, we'll get your finances on track.")
                    .font(.system(size: 18, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.14))
                .frame(height: 270)
                .overlay {
                    Image("Jar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                }
                .padding(.horizontal, 24)

            Spacer()

            // swipe hint
            VStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                Text("Swipe up")
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(.vertical, 32)
    }
}
