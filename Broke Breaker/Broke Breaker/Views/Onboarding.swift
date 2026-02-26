import SwiftUI
import UIKit
import CoreHaptics

// MARK: - App Entry Demo

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                MainAppPlaceholder()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                OnboardingFlow {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }
}

struct MainAppPlaceholder: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "creditcard.circle.fill")
                    .font(.system(size: 64))
                Text("Broke Breaker")
                    .font(.largeTitle.bold())
                Text("Main app goes here.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    enum Page: Int, CaseIterable {
        case welcome, track, spendToday, rollover, contract, letsGo
    }

    @State private var page: Page = .welcome
    @State private var contractSigned: Bool = false
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    WelcomeSlide().tag(Page.welcome)

                    InfoSlide(
                        icon: "tray.full.fill",
                        title: "Track everything",
                        subtitle: "Log one-offs, bills, subscriptions, and income in one place."
                    )
                    .tag(Page.track)

                    InfoSlide(
                        icon: "calendar.day.timeline.left",
                        title: "Know what you can spend today",
                        subtitle: "Broke Breaker spreads your money across the next months so you don’t accidentally future-you."
                    )
                    .tag(Page.spendToday)

                    InfoSlide(
                        icon: "arrow.up.right.circle.fill",
                        title: "Unused money rolls over",
                        subtitle: "Spend less today, and tomorrow’s budget grows. Simple. Satisfying."
                    )
                    .tag(Page.rollover)

                    ContractSlide(isSigned: $contractSigned)
                        .tag(Page.contract)

                    FinalSlide().tag(Page.letsGo)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: page)

                VStack(spacing: 12) {
                    PageDots(current: page.rawValue, total: Page.allCases.count)

                    HStack(spacing: 12) {
                        if page != .welcome {
                            Button("Back") { goBack() }
                                .buttonStyle(SecondaryPillButton())
                        }

                        Spacer()

                        Button(page == .letsGo ? "Enter Broke Breaker" : "Continue") {
                            if page == .letsGo { onFinish() }
                            else { advance() }
                        }
                        .buttonStyle(PrimaryPillButton())
                        .disabled(page == .contract && !contractSigned)
                        .opacity((page == .contract && !contractSigned) ? 0.55 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
                .padding(.top, 12)
                .background(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea()
    }

    private func advance() {
        if let next = Page(rawValue: page.rawValue + 1) { page = next }
    }

    private func goBack() {
        if let prev = Page(rawValue: page.rawValue - 1) { page = prev }
    }
}

// MARK: - Slides

struct WelcomeSlide: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // Optional logo asset: add "BrokeBreakerLogo" to Assets.xcassets
            Group {
                if let uiImage = UIImage(named: "BrokeBreakerLogo") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(radius: 16, y: 10)
                } else {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 96))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .white.opacity(0.65))
                        .shadow(radius: 16, y: 10)
                }
            }

            Text("Welcome to\nBroke Breaker")
                .font(.system(.largeTitle, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("A tiny app with a big goal: stop surprise broke.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 28)

            Spacer()

            FloatingIconsRow()
                .padding(.bottom, 30)
        }
        .padding(.top, 40)
    }
}

struct InfoSlide: View {
    let icon: String
    let title: String
    let subtitle: String

    @State private var bob = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 170, height: 170)

                Image(systemName: icon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(y: bob ? -6 : 6)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
                    .onAppear { bob = true }
            }
            .shadow(radius: 16, y: 10)

            Text(title)
                .font(.system(.title, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            Text(subtitle)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.top, 40)
    }
}

struct ContractSlide: View {
    @Binding var isSigned: Bool

    @State private var progress: CGFloat = 0
    @State private var isHolding = false

    // 10s hold
    private let holdDuration: Double = 10.0

    // progress drains fast when not holding
    private let decayRatePerSecond: Double = 2.8

    @State private var timer: Timer?
    @State private var lastTick = Date()

    @State private var haptics = HapticRiser()

    // completion anim
    @State private var didCompletePulse = false
    @State private var didCompleteCheck = false

    // NEW
    @State private var showConfetti = false
    @State private var showCongratsText = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 14) {
                Text("The Tiny Contract")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("Hold to sign:")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))

                Text("“I will stay in control of my money, spend intentionally, and protect future-me from surprise broke.”")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.top, 6)
            }

            Spacer()

            // staged status text ABOVE the circle, only while holding and not done
            Text(stageText)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .opacity((isHolding && !isSigned) ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHolding)
                .padding(.bottom, 6)

            let ringSize: CGFloat = 178
            let ringLine: CGFloat = 10

            ZStack {

                // Background ring (no trim) — strokeBorder is fine here
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: ringLine)
                    .frame(width: ringSize, height: ringSize)

                // Progress ring (trim breaks strokeBorder) — use stroke + padding
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: ringLine, lineCap: .round))
                    .frame(width: ringSize, height: ringSize)
                    .padding(ringLine / 2)                 // <-- prevents clipping
                    .rotationEffect(Angle.degrees(-90))    // explicit Angle fixes the .degrees error
                    .transaction { $0.animation = nil }
                    .drawingGroup()

                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .frame(width: 156, height: 156)
                    .scaleEffect(didCompletePulse ? 1.06 : 1.0)
                    .opacity(isSigned ? 1 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: didCompletePulse)

                if isSigned && didCompleteCheck {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }

                HoldButton(
                    title: isSigned ? "" : "Hold to Sign",
                    isDisabled: isSigned,
                    onPressBegan: pressBegan,
                    onPressEnded: pressEnded
                )
                .frame(width: 146, height: 146)
                .scaleEffect(isHolding && !isSigned ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isHolding)
            }
            .padding(.bottom, 6)
            .overlay {
                if showConfetti {
                    ConfettiEmitter(
                        size: ringSize * 3.2,
                        emissionDuration: 5,   // spawns for 2.5s
                        rate: 125                // 70 particles/sec
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .transaction { $0.animation = nil }
                }
            }

            Text("CONGRATS! You've just become the main character in your own finances.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 24)
                .opacity(showCongratsText ? 1 : 0)
                .offset(y: showCongratsText ? 0 : 8)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showCongratsText)

            Spacer()
        }
        .padding(.top, 40)
        .onAppear { haptics.prepare() }
        .onDisappear { stopTicker() }
        .onChange(of: isSigned) { _, newValue in
            if newValue { stopTicker() }
        }
    }

    // MARK: - Missing helpers (these fix your compile errors)

    private var stageText: String {
        let t = Double(progress) * holdDuration
        if t < 2 { return "Analyzing fingerprint" }
        if t < 4 { return "Detecting spending habits" }
        if t < 6 { return "Determining solution" }
        if t < 8 { return "The solution to your spending problems is..." }
        if t < 10 { return "BROKE BREAKER!" }
        return ""
    }

    private func pressBegan() {
        guard !isSigned else { return }
        if !isHolding {
            isHolding = true
            haptics.start()
            startTickerIfNeeded()
        }
    }

    private func pressEnded() {
        guard !isSigned else { return }
        isHolding = false
        haptics.release()
        startTickerIfNeeded()
    }

    private func startTickerIfNeeded() {
        if timer != nil { return }
        lastTick = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            tick()
        }
    }

    private func stopTicker() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isSigned else { stopTicker(); return }

        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now

        var p = Double(progress)

        if isHolding {
            p += dt / holdDuration
            p = min(1.0, p)
        } else {
            p -= dt * decayRatePerSecond
            p = max(0.0, p)
        }

        let newProgress = CGFloat(p)
        withTransaction(Transaction(animation: nil)) {
            progress = newProgress
        }

        if isHolding { haptics.update(progress: p) }

        if p >= 1.0 { complete() }
        else if !isHolding && p <= 0.0001 { stopTicker() }
    }

    private func complete() {
        guard !isSigned else { return }
        isHolding = false
        isSigned = true
        withTransaction(Transaction(animation: nil)) {
            progress = 1.0
        }

        haptics.success()

        didCompleteCheck = false
        didCompletePulse = true

        // confetti + congrats
        withAnimation(.easeOut(duration: 0.15)) {
            showConfetti = true
            showCongratsText = true
        }
        let emissionDuration: Double = 3.5
        let maxLifetime: Double = 1.2
        let total = emissionDuration + maxLifetime + 0.5

        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            withAnimation(.easeOut(duration: 0.35)) {
                showConfetti = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                didCompleteCheck = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            didCompletePulse = false
        }

        stopTicker()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            haptics.pulse(strength: 9999999999.0)
        }

    }
}

struct FinalSlide: View {
    @State private var pop = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(pop ? 2 : -2))
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pop)
                    .onAppear { pop = true }

                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(radius: 16, y: 10)

            Text("You’re ready.")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(.white)

            Text("Open the app, add your transactions,\nand let tomorrow chill.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.top, 40)
    }
}

// MARK: - Components

struct HoldButton: View {
    let title: String
    let isDisabled: Bool
    let onPressBegan: () -> Void
    let onPressEnded: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(isDisabled ? 0.18 : 0.22))
                .overlay(
                    Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                )

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(16)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isDisabled else { return }
                    onPressBegan()
                }
                .onEnded { _ in
                    guard !isDisabled else { return }
                    onPressEnded()
                }
        )
        .accessibilityLabel(title)
    }
}

struct PageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i == current ? 0.95 : 0.35))
                    .frame(width: i == current ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: current)
            }
        }
        .padding(.top, 8)
    }
}

struct PrimaryPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white, in: Capsule())
            .opacity(configuration.isPressed ? 0.78 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AnimatedBackground: View {
    @State private var drift = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.18, blue: 0.45),
                Color(red: 0.10, green: 0.45, blue: 0.55),
                Color(red: 0.12, green: 0.12, blue: 0.20)
            ],
            startPoint: drift ? .topLeading : .topTrailing,
            endPoint: drift ? .bottomTrailing : .bottomLeading
        )
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
        .overlay(
            // “Cinema dust” blobs
            ZStack {
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 240, height: 240)
                    .blur(radius: 30)
                    .offset(x: drift ? -130 : -80, y: drift ? -220 : -180)

                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 34)
                    .offset(x: drift ? 140 : 90, y: drift ? -70 : -110)

                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 280, height: 280)
                    .blur(radius: 32)
                    .offset(x: drift ? 120 : 160, y: drift ? 240 : 200)
            }
        )
    }
}

struct FloatingIconsRow: View {
    @State private var float = false

    var body: some View {
        HStack(spacing: 22) {
            floatingIcon("chart.line.uptrend.xyaxis")
            floatingIcon("calendar")
            floatingIcon("banknote")
            floatingIcon("lock.shield")
        }
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white.opacity(0.9))
        .offset(y: float ? -6 : 6)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: float)
        .onAppear { float = true }
    }

    private func floatingIcon(_ name: String) -> some View {
        Image(systemName: name)
            .padding(12)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
    }
}

// MARK: - Preview

struct HapticRiser {
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?

    private let touchDown = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    private var lastParamSend: TimeInterval = 0
    private var nextPulseTime: TimeInterval = 0

    mutating func prepare() {
        touchDown.prepare()
        notify.prepare()

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()

            // Keep it alive + recover if the system stops it.
            engine?.stoppedHandler = { reason in
                // You can log reason if you want.
            }
            engine?.resetHandler = { [weakEngine = engine] in
                // Engine got reset, restart it.
                do { try weakEngine?.start() } catch { }
            }

            engine?.isAutoShutdownEnabled = false
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    mutating func start() {
        touchDown.impactOccurred(intensity: 1.0)

        guard let engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            // Strong baseline continuous "motor"
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    // Start noticeably strong
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ],
                relativeTime: 0,
                duration: 60
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: 0)

            lastParamSend = 0
            nextPulseTime = 0
        } catch {
            continuousPlayer = nil
        }
    }
    
    @inline(__always)
    func ramp(_ p: Double, shape: Double = 1.35) -> Double {
        let x = max(0, min(1, p))
        let s = x * x * (3 - 2 * x)     // smoothstep
        return pow(s, shape)            // shape > 1 delays early energy slightly
    }

    mutating func update(progress: Double) {
        guard let engine else { return }

        let p = max(0, min(1, progress))

        let eased = ramp(p, shape: 1.45)

        // Start near 0, end at 1
        let intensity = Float(0.02 + 0.98 * eased)   // 0.02 -> 1.0
        let sharpness = Float(0.02 + 0.98 * eased)   // 0.02 -> 1.0

        // Throttle param sends (60Hz is overkill; 20–30Hz feels the same)
        let now = CACurrentMediaTime()
        if now - lastParamSend > (1.0 / 30.0) {
            lastParamSend = now

            if let player = continuousPlayer {
                do {
                    let i = CHHapticDynamicParameter(
                        parameterID: .hapticIntensityControl,
                        value: intensity,
                        relativeTime: 0
                    )
                    let s = CHHapticDynamicParameter(
                        parameterID: .hapticSharpnessControl,
                        value: sharpness,
                        relativeTime: 0
                    )
                    try player.sendParameters([i, s], atTime: 0)
                } catch { }
            }
        }

        // Add "rumble texture" using transients (controller-ish feel)
        // Pulse interval shrinks as progress increases.
        let minInterval: TimeInterval = 0.035
        let maxInterval: TimeInterval = 0.16
        let interval = max(minInterval, maxInterval - (maxInterval - minInterval) * eased)

        if now >= nextPulseTime {
            nextPulseTime = now + interval
            playRumblePulse(engine: engine, strength: eased)
        }
    }

    mutating func release() {
        stopContinuous()
        // optional: tiny release cue
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.35)
    }

    mutating func success() {
        stopContinuous()
        notify.notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
    }

    mutating func cancel() {
        stopContinuous()
        notify.notificationOccurred(.warning)
    }

    private mutating func stopContinuous() {
        do { try continuousPlayer?.stop(atTime: 0) } catch { }
        continuousPlayer = nil
    }

    private func playRumblePulse(engine: CHHapticEngine, strength: Double) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let v = Float(0.02 + 0.98 * strength)
        let s = Float(0.02 + 0.98 * strength)

        do {
            let pulse = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: v),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: s)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [pulse], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch { }
    }
    
    mutating func pulse(strength: Double) {
        guard let engine else { return }
        playRumblePulse(engine: engine, strength: max(0, min(1, strength)))
    }
}

struct ConfettiEmitter: View {
    private struct Particle: Identifiable {
        let id = UUID()
        let birth: Double
        let lifetime: Double

        let vx0: Double
        let vy0: Double
        let spin: Double

        let size: CGFloat
        let color: Color
        let shape: ShapeKind

        enum ShapeKind { case rect, circle }
    }
    let size: CGFloat                 // canvas size (square)
    let emissionDuration: Double      // how long we keep spawning particles
    let rate: Double                  // particles per second
    let particleLifetime: ClosedRange<Double> = 3.2...10.2

    // motion tuning
    let gravity: Double = 85.0   // was 140
    let drag: Double = 0.96      // was 0.92 (less damping = floatier)
    let spreadDegrees: ClosedRange<Double> = 0...360
    let speedRange: ClosedRange<Double> = 80...220
    let spinRange: ClosedRange<Double> = -220...220
    let sizeRange: ClosedRange<CGFloat> = 6...14

    @State private var t0: Double = 0
    @State private var lastT: Double = 0
    @State private var carry: Double = 0
    @State private var particles: [Particle] = []

    // seeded RNG so it’s stable per run but still “random-looking”
    @State private var rng = SeededGenerator(seed: UInt64.random(in: 0..<UInt64.max))

    private let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink]

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let started = (t0 != 0)

            let t = started ? (now - t0) : 0
            let dt = started ? max(0, now - lastT) : 0

            Canvas { ctx, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

                // draw
                for p in particles {
                    let age = t - p.birth
                    if age < 0 || age > p.lifetime { continue }

                    let alpha = max(0, 1 - (age / p.lifetime))
                    ctx.opacity = alpha

                    // drag-ish damping
                    let damp = pow(drag, age)

                    // velocities
                    let vx = p.vx0 * damp
                    let vy = p.vy0 * damp

                    let x = center.x + CGFloat(vx * age)
                    let y = center.y + CGFloat(vy * age) + CGFloat(0.5 * gravity * age * age)

                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: x, y: y)
                    transform = transform.rotated(by: CGFloat((p.spin * age) * .pi / 180))
                    transform = transform.translatedBy(x: -p.size/2, y: -p.size/2)

                    let path: Path = {
                        switch p.shape {
                        case .circle:
                            return Path(ellipseIn: CGRect(x: 0, y: 0, width: p.size, height: p.size))
                        case .rect:
                            return Path(CGRect(x: 0, y: 0, width: p.size, height: p.size * 0.6))
                        }
                    }()

                    ctx.fill(path.applying(transform), with: .color(p.color))
                }
            }
            .onAppear {
                if t0 == 0 {
                    t0 = now
                    lastT = now
                }
            }
            .onChange(of: now) { _, _ in
                guard t0 != 0 else { return }
                step(now: now)
            }
        }
        .frame(width: size, height: size)
    }

    private func step(now: Double) {
        let t = now - t0
        let dt = max(0, now - lastT)
        lastT = now

        // Emit over time
        if t <= emissionDuration {
            carry += rate * dt
            let toEmit = Int(carry)
            if toEmit > 0 {
                carry -= Double(toEmit)
                for _ in 0..<toEmit {
                    particles.append(makeParticle(currentTime: t))
                }
            }
        }

        // Cull dead particles (keeps array from growing forever)
        particles.removeAll { (t - $0.birth) > $0.lifetime + 0.1 }
    }

        private func makeParticle(currentTime t: Double) -> Particle {
            let lifetime = Double.random(in: particleLifetime, using: &rng)
            let spin = Double.random(in: spinRange, using: &rng)
            let size = CGFloat.random(in: sizeRange, using: &rng)
            let shape: Particle.ShapeKind = (Double.random(in: 0...1, using: &rng) < 0.33) ? .circle : .rect
            let color = colors[Int.random(in: 0..<colors.count, using: &rng)]

            // tiny birth jitter
            let jitter = Double.random(in: -0.06...0.06, using: &rng)
            let birth = max(0, t + jitter)

            // "occasionally thrown up" early
            let early = t < 1.2
            let toss = early && (Double.random(in: 0...1, using: &rng) < 0.22)

            // horizontal drift
            let vx0 = Double.random(in: -140...140, using: &rng)

            // vertical launch:
            // toss => strong upward (negative)
            // normal => mild upward or slight downward
            let vy0: Double = {
                if toss { return Double.random(in: -320...(-180), using: &rng) }   // YEET upward
                else { return Double.random(in: -120...40, using: &rng) }          // mostly float
            }()

            // optional: toss particles also start faster sideways
            let boostedVx0 = toss ? vx0 * Double.random(in: 1.2...1.8, using: &rng) : vx0

            return Particle(
                birth: birth,
                lifetime: lifetime,
                vx0: boostedVx0,
                vy0: vy0,
                spin: spin,
                size: size,
                color: color,
                shape: shape
            )
        }
}

// Simple seeded RNG (SplitMix64)
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

#Preview {
    ContentView()
}
