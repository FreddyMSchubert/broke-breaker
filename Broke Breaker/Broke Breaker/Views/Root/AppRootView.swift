import SwiftUI

struct AppRootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            RootTabView()

            if !hasSeenOnboarding {
                OnboardingPagerView(
                    slides: OnboardingSlide.demoSlides,
                    onFinished: {
                        hasSeenOnboarding = true
                    }
                )
                .transition(.identity)
                .zIndex(1)
            }
        }
    }
}
