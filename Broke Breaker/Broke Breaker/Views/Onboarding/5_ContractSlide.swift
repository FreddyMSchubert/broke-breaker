import SwiftUI
import CoreHaptics

// MARK: - Contract Slide

struct ContractSlideView: View {
    @State private var isSigned = false
    @State private var progress: CGFloat = 0
    @State private var isHolding = false

    @State private var timer: Timer?
    @State private var lastTick = Date()
    @State private var haptics = HapticRiser()

    @State private var didCompletePulse = false
    @State private var didCompleteCheck = false
    @State private var showConfetti = false
    @State private var showCongratsText = false

    private let holdDuration: Double = 10.0
    private let decayRatePerSecond: Double = 2.8

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            headerSection

            Spacer()

            Text(stageText)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .opacity((isHolding && !isSigned) ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHolding)
                .padding(.bottom, 6)

            signingControl
                .padding(.bottom, 6)
                .overlay {
                    if showConfetti {
                        ConfettiEmitter(
                            size: 178 * 3.2,
                            emissionDuration: 5,
                            rate: 125
                        )
                        .allowsHitTesting(false)
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
        .onAppear {
            haptics.prepare()
        }
        .onDisappear {
            stopTicker()
        }
        .onChange(of: isSigned) { _, newValue in
            if newValue {
                stopTicker()
            }
        }
    }
}

// MARK: - View Sections

private extension ContractSlideView {
    var headerSection: some View {
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
    }

    var signingControl: some View {
        let ringSize: CGFloat = 178
        let ringLine: CGFloat = 10

        return ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: ringLine)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: ringLine, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .padding(ringLine / 2)
                .rotationEffect(.degrees(-90))
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
    }

    var stageText: String {
        let t = Double(progress) * holdDuration

        if t < 2 { return "Analyzing fingerprint" }
        if t < 4 { return "Detecting spending habits" }
        if t < 6 { return "Determining solution" }
        if t < 8 { return "The solution to your spending problems is..." }
        if t < 10 { return "BROKE BREAKER!" }
        return ""
    }
}

// MARK: - Interaction

private extension ContractSlideView {
    func pressBegan() {
        guard !isSigned else { return }

        if !isHolding {
            isHolding = true
            haptics.start()
            startTickerIfNeeded()
        }
    }

    func pressEnded() {
        guard !isSigned else { return }

        isHolding = false
        haptics.release()
        startTickerIfNeeded()
    }

    func startTickerIfNeeded() {
        guard timer == nil else { return }

        lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            tick()
        }
    }

    func stopTicker() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        guard !isSigned else {
            stopTicker()
            return
        }

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

        withTransaction(Transaction(animation: nil)) {
            progress = CGFloat(p)
        }

        if isHolding {
            haptics.update(progress: p)
        }

        if p >= 1.0 {
            complete()
        } else if !isHolding && p <= 0.0001 {
            stopTicker()
        }
    }

    func complete() {
        guard !isSigned else { return }

        isHolding = false
        isSigned = true

        withTransaction(Transaction(animation: nil)) {
            progress = 1.0
        }

        haptics.success()

        didCompleteCheck = false
        didCompletePulse = true

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
            haptics.pulse(strength: 1.0)
        }
    }
}

// MARK: - Hold Button

private struct HoldButton: View {
    let title: String
    let isDisabled: Bool
    let onPressBegan: () -> Void
    let onPressEnded: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(isDisabled ? 0.18 : 0.22))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
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

// MARK: - Haptics

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

            engine?.stoppedHandler = { _ in
            }

            engine?.resetHandler = { [weakEngine = engine] in
                do {
                    try weakEngine?.start()
                } catch {
                }
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
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
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
        let s = x * x * (3 - 2 * x)
        return pow(s, shape)
    }

    mutating func update(progress: Double) {
        guard let engine else { return }

        let p = max(0, min(1, progress))
        let eased = ramp(p, shape: 1.45)

        let intensity = Float(0.02 + 0.98 * eased)
        let sharpness = Float(0.02 + 0.98 * eased)

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
                } catch {
                }
            }
        }

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

    mutating func pulse(strength: Double) {
        guard let engine else { return }
        playRumblePulse(engine: engine, strength: max(0, min(1, strength)))
    }

    private mutating func stopContinuous() {
        do {
            try continuousPlayer?.stop(atTime: 0)
        } catch {
        }
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
        } catch {
        }
    }
}

// MARK: - Confetti

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

        enum ShapeKind {
            case rect
            case circle
        }
    }

    let size: CGFloat
    let emissionDuration: Double
    let rate: Double

    private let particleLifetime: ClosedRange<Double> = 3.2...10.2
    private let gravity: Double = 85.0
    private let drag: Double = 0.96
    private let spinRange: ClosedRange<Double> = -220...220
    private let sizeRange: ClosedRange<CGFloat> = 6...14

    @State private var t0: Double = 0
    @State private var lastT: Double = 0
    @State private var carry: Double = 0
    @State private var particles: [Particle] = []
    @State private var rng = SeededGenerator(seed: UInt64.random(in: 0..<UInt64.max))

    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let started = t0 != 0
            let t = started ? (now - t0) : 0

            Canvas { ctx, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

                for p in particles {
                    let age = t - p.birth
                    if age < 0 || age > p.lifetime { continue }

                    let alpha = max(0, 1 - (age / p.lifetime))
                    ctx.opacity = alpha

                    let damp = pow(drag, age)
                    let vx = p.vx0 * damp
                    let vy = p.vy0 * damp

                    let x = center.x + CGFloat(vx * age)
                    let y = center.y + CGFloat(vy * age) + CGFloat(0.5 * gravity * age * age)

                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: x, y: y)
                    transform = transform.rotated(by: CGFloat((p.spin * age) * .pi / 180))
                    transform = transform.translatedBy(x: -p.size / 2, y: -p.size / 2)

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

        particles.removeAll { (t - $0.birth) > $0.lifetime + 0.1 }
    }

    private func makeParticle(currentTime t: Double) -> Particle {
        let lifetime = Double.random(in: particleLifetime, using: &rng)
        let spin = Double.random(in: spinRange, using: &rng)
        let size = CGFloat.random(in: sizeRange, using: &rng)
        let shape: Particle.ShapeKind = Double.random(in: 0...1, using: &rng) < 0.33 ? .circle : .rect
        let color = colors[Int.random(in: 0..<colors.count, using: &rng)]

        let jitter = Double.random(in: -0.06...0.06, using: &rng)
        let birth = max(0, t + jitter)

        let early = t < 1.2
        let toss = early && (Double.random(in: 0...1, using: &rng) < 0.22)

        let vx0 = Double.random(in: -140...140, using: &rng)
        let vy0: Double = toss
            ? Double.random(in: -320 ... -180, using: &rng)
            : Double.random(in: -120 ... 40, using: &rng)

        let boostedVx0 = toss
            ? vx0 * Double.random(in: 1.2...1.8, using: &rng)
            : vx0

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

// MARK: - Seeded RNG

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
