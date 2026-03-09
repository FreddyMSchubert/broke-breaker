import SwiftUI
import UIKit

// MARK: - Pager

struct OnboardingPagerView: View {
    let slides: [OnboardingSlide]
    let onFinished: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isCompleting = false

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width

            ZStack {
                interpolatedBackground(pageHeight: height)
                    .ignoresSafeArea()

                slidesLayer(size: geo.size)
            }
            .contentShape(Rectangle())
            .offset(y: overlayOffset(pageHeight: height))
            .opacity(finalDismissOpacity(pageHeight: height))
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard !isCompleting else { return }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        guard !isCompleting else { return }

                        let translation = value.translation.height
                        let threshold = height * 0.18

                        if translation < -threshold {
                            if currentIndex < slides.count - 1 {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                    currentIndex += 1
                                    dragOffset = 0
                                }
                            } else {
                                completeOnboarding(pageHeight: height)
                            }
                        } else if translation > threshold, currentIndex > 0 {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                currentIndex -= 1
                                dragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .frame(width: width, height: height)
        }
    }
    
    private func finalDismissOpacity(pageHeight: CGFloat) -> Double {
        guard currentIndex == slides.count - 1, dragOffset < 0 else { return 1 }
        let progress = min(abs(dragOffset) / pageHeight, 1)
        return 1 - (progress * 0.12)
    }

    @ViewBuilder
    private func slidesLayer(size: CGSize) -> some View {
        let height = size.height

        ZStack {
            ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                slide.view
                    .frame(width: size.width, height: size.height)
                    .offset(y: yOffset(for: index, pageHeight: height))
                    .scaleEffect(scale(for: index, pageHeight: height))
                    .opacity(opacity(for: index, pageHeight: height))
                    .animation(.interactiveSpring(response: 0.36, dampingFraction: 0.88), value: currentIndex)
                    .animation(.interactiveSpring(response: 0.36, dampingFraction: 0.88), value: dragOffset)
            }
        }
    }

    private func yOffset(for index: Int, pageHeight: CGFloat) -> CGFloat {
        let base = CGFloat(index - currentIndex) * pageHeight
        return base + dragOffset
    }

    private func overlayOffset(pageHeight: CGFloat) -> CGFloat {
        guard currentIndex == slides.count - 1, dragOffset < 0 else {
            return isCompleting ? -pageHeight : 0
        }

        return dragOffset
    }

    private func scale(for index: Int, pageHeight: CGFloat) -> CGFloat {
        let distance = abs(yOffset(for: index, pageHeight: pageHeight) / pageHeight)
        return max(0.94, 1 - (distance * 0.06))
    }

    private func opacity(for index: Int, pageHeight: CGFloat) -> Double {
        let distance = abs(yOffset(for: index, pageHeight: pageHeight) / pageHeight)
        return max(0.35, 1 - (distance * 0.55))
    }

    @ViewBuilder
    private func interpolatedBackground(pageHeight: CGFloat) -> some View {
        let palette = backgroundTransitionPalette(pageHeight: pageHeight)

        LinearGradient(
            colors: [palette.top, palette.bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func backgroundTransitionPalette(pageHeight: CGFloat) -> (top: Color, bottom: Color) {
        let current = slides[currentIndex].palette(for: colorScheme)

        guard dragOffset < 0, currentIndex < slides.count - 1 else {
            return (current.top, current.bottom)
        }

        let next = slides[currentIndex + 1].palette(for: colorScheme)
        let progress = min(abs(dragOffset) / pageHeight, 1)

        return (
            top: current.top.mix(with: next.top, progress: progress),
            bottom: current.bottom.mix(with: next.bottom, progress: progress)
        )
    }

    private func completeOnboarding(pageHeight: CGFloat) {
        guard !isCompleting else { return }

        isCompleting = true

        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            dragOffset = -pageHeight
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onFinished()
        }
    }
}


// MARK: - Model

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let topRGB: RGBColor
    let bottomRGB: RGBColor
    let view: AnyView

    func palette(for scheme: ColorScheme) -> (top: Color, bottom: Color) {
        switch scheme {
        case .dark:
            return (topRGB.color, bottomRGB.color)
        default:
            return (
                topRGB.lightened(by: 0.32).color,
                bottomRGB.lightened(by: 0.32).color
            )
        }
    }
}

struct RGBColor {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = min(max(red, 0), 255)
        self.green = min(max(green, 0), 255)
        self.blue = min(max(blue, 0), 255)
    }

    var color: Color {
        Color(
            red: red / 255,
            green: green / 255,
            blue: blue / 255
        )
    }

    func lightened(by amount: Double) -> RGBColor {
        RGBColor(
            red + (255 - red) * amount,
            green + (255 - green) * amount,
            blue + (255 - blue) * amount
        )
    }
}

// MARK: - Demo Data

extension OnboardingSlide {
    static let demoSlides: [OnboardingSlide] = [
        OnboardingSlide(
            topRGB: RGBColor(102, 0, 227),
            bottomRGB: RGBColor(136, 0, 143),
            view: AnyView(WelcomeSlideView())
        ),
        OnboardingSlide(
            topRGB: RGBColor(26, 51, 117),
            bottomRGB: RGBColor(10, 26, 66),
            view: AnyView(IncomeSlideView())
        ),
        OnboardingSlide(
            topRGB: RGBColor(107, 20, 36),
            bottomRGB: RGBColor(56, 8, 18),
            view: AnyView(ExpenseSlideView())
        ),
        OnboardingSlide(
            topRGB: RGBColor(20, 56, 36),
            bottomRGB: RGBColor(33, 87, 46),
            view: AnyView(WatchNumberSlideView())
        ),
        OnboardingSlide(
            topRGB: RGBColor(0, 0, 0),
            bottomRGB: RGBColor(0, 0, 0),
            view: AnyView(ContractSlideView())
        ),
        OnboardingSlide(
            topRGB: RGBColor(0, 156, 127),
            bottomRGB: RGBColor(0, 86, 94),
            view: AnyView(ReadyToStartSlideView())
        )
    ]
}

// MARK: - Color interpolation

extension Color {
    func mix(with other: Color, progress: CGFloat) -> Color {
        let p = min(max(progress, 0), 1)

        let c1 = UIColor(self)
        let c2 = UIColor(other)

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0

        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return Color(
            red: r1 + (r2 - r1) * p,
            green: g1 + (g2 - g1) * p,
            blue: b1 + (b2 - b1) * p,
            opacity: a1 + (a2 - a1) * p
        )
    }
}

// MARK: - Preview

#Preview {
    AppRootView()
}
