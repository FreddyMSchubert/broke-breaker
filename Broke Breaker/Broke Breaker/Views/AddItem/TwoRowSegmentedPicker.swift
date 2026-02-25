import SwiftUI

// MARK: - Public component

struct TwoRowSegmentedPicker<Option: Hashable & RawRepresentable>: View where Option.RawValue == String {
    let options: [Option]
    @Binding var selection: Option

    var itemSpacing: CGFloat = 12
    var lineSpacing: CGFloat = 10
    var padding: CGFloat = 12

    @Namespace private var ns

    var body: some View {
        VStack(alignment: .center, spacing: lineSpacing) {
            HStack(spacing: itemSpacing) {
                if options.indices.contains(0) { segment(options[0]) }
                if options.indices.contains(1) { segment(options[1]) }
            }
            HStack(spacing: itemSpacing) {
                if options.indices.contains(2) { segment(options[2]) }
            }
        }
        .padding(padding)
        .fixedSize(horizontal: true, vertical: true)
        .animation(.easeInOut(duration: 0.22), value: selection)
        .accessibilityElement(children: .contain)
    }

    private func segment(_ opt: Option) -> some View {
        let isSelected = (opt == selection)

        return Button { selection = opt } label: {
            Text(opt.rawValue)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        pill.matchedGeometryEffect(id: "pill", in: ns)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var pill: some View {
        Group {
            if #available(iOS 26.0, *) {
                Capsule().glassEffect(.regular, in: Capsule())
            } else {
                Capsule().fill(.thinMaterial)
            }
        }
    }
}
