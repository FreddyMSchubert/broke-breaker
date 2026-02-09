import SwiftUI
import SwiftData

struct FakeCaret: View {
    @State private var on = true
    var height: CGFloat = 26

    var body: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(width: 2, height: height)
            .opacity(on ? 1 : 0)
            .onAppear { on.toggle() }
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: on)
    }
}
