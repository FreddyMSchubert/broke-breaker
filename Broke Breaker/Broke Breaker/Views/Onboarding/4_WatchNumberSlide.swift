import SwiftUI

struct WatchNumberSlideView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("This is the number you need to watch.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 18) {
                ZStack {
                    Image("number_graphic")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 283, height: 145)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(spacing: 12) {
                    Text("It tells you how much money you can still spend today without worrying you'll fall behind at the end of the month.")
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)

                    Text("Good for peace of mind, isn't it?")
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.vertical, 32)
    }
}
