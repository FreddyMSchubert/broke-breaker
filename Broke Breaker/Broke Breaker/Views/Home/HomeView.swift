import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome. This is the main page.")
                .foregroundStyle(.secondary)
            
            Text("This is where Faith will be putting a nice display of the current days spendable money and the next few days somehow. Should be fancy for good screenshots");

            Spacer()
        }
        .padding()
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack { HomeView() }
}
