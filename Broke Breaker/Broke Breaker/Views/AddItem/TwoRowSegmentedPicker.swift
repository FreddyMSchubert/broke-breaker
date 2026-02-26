import SwiftUI

struct TwoRowSegmentedPicker<Option: Hashable & RawRepresentable>: View where Option.RawValue == String {
    let options: [Option]
    @Binding var selection: Option

    var textColor: Color = .secondary
    var highlightedTextColor: Color = .primary

    var itemSpacing: CGFloat = 12
    var lineSpacing: CGFloat = 10
    var padding: CGFloat = 12

    var animationDuration: Double = 0.22
    var recolorDelayFraction: Double = 0.5

    @Namespace private var ns
    @Environment(\.colorScheme) private var colorScheme

    @State private var visualSelection: Option
    @State private var recolorTask: Task<Void, Never>?

    init(
        options: [Option],
        selection: Binding<Option>,
        textColor: Color = .secondary,
        highlightedTextColor: Color = .primary,
        itemSpacing: CGFloat = 12,
        lineSpacing: CGFloat = 10,
        padding: CGFloat = 12,
        animationDuration: Double = 0.22,
        recolorDelayFraction: Double = 0.5
    ) {
        self.options = options
        self._selection = selection
        self.textColor = textColor
        self.highlightedTextColor = highlightedTextColor
        self.itemSpacing = itemSpacing
        self.lineSpacing = lineSpacing
        self.padding = padding
        self.animationDuration = animationDuration
        self.recolorDelayFraction = recolorDelayFraction

        _visualSelection = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        let firstRow = Array(options.prefix(2))
        let secondRow = Array(options.dropFirst(2))

        VStack(alignment: .center, spacing: lineSpacing) {
            row(firstRow)
            if !secondRow.isEmpty { row(secondRow) }
        }
        .padding(padding)
        .fixedSize(horizontal: true, vertical: true)
        .animation(.easeInOut(duration: animationDuration), value: selection)
        .onChange(of: selection) { _, newValue in
            scheduleRecolor(to: newValue)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func row(_ opts: [Option]) -> some View {
        HStack(spacing: itemSpacing) {
            ForEach(opts, id: \.self) { opt in
                segment(opt)
            }
        }
    }

    private func segment(_ opt: Option) -> some View {
        let isPillSelected = (opt == selection)
        let isTextSelected = (opt == visualSelection)

        return Button {
            selection = opt
            scheduleRecolor(to: opt)
        } label: {
            Text(opt.rawValue)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(isTextSelected ? highlightedTextColor : textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if isPillSelected {
                        pill.matchedGeometryEffect(id: "pill", in: ns)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPillSelected ? [.isSelected] : [])
    }

    private func scheduleRecolor(to newValue: Option) {
        recolorTask?.cancel()
        let delay = animationDuration * recolorDelayFraction

        recolorTask = Task {
            let ns = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            await MainActor.run { visualSelection = newValue }
        }
    }

    // MARK: - Highlight blob (lighter in Light Mode)

    private var pill: some View {
        let lightOpacity: CGFloat = 0.55
        let darkOpacity: CGFloat = 0.90
        let materialOpacity = (colorScheme == .light) ? lightOpacity : darkOpacity

        return Group {
            Capsule()
                .glassEffect(.regular, in: Capsule())
                .opacity(materialOpacity)
                .overlay {
                    Capsule().strokeBorder(.primary.opacity(colorScheme == .light ? 0.10 : 0.18), lineWidth: 1)
                }
        }
        .shadow(
            color: .black.opacity(colorScheme == .light ? 0.06 : 0.20),
            radius: colorScheme == .light ? 6 : 10,
            x: 0, y: 2
        )
    }
}
