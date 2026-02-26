import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedCurrencyCode") private var selectedCurrencyCode: String = "GBP"
    @AppStorage("hasSeenOnboarding") private var onboardingResetToken: Bool = true

    private let currencyCodes: [String] = Locale.commonISOCurrencyCodes.sorted()
    
    private let names: [String] = [
        "Calum Lane",
        "Faith Oyemike",
        "Frederick Schubert",
        "Karen Jandira Fernandes Dos Santos",
        "Isha Bangura",
        "Omar Omar"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Reset Onboarding Sequence", role: .destructive) {
                        onboardingResetToken = false
                    }
                    
                    Picker("Currency", selection: $selectedCurrencyCode) {
                        ForEach(currencyCodes, id: \.self) { code in
                            Text(displayName(for: code)).tag(code)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        
        Section {
            Text("Broke Breaker - Created by")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
            ForEach(names.shuffled(), id: \.self) { name in
                Text(name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func displayName(for code: String) -> String {
        // Show a friendly name if available; fall back to the code.
        // Locale has localized strings for currency codes.
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        return "\(code) (\(name))"
    }
}

#Preview { SettingsView() }
