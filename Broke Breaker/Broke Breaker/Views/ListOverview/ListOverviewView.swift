import SwiftUI

struct ListOverviewView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome. This is the list overview page.")
                .foregroundStyle(.secondary)
            
            Text("This is where Calum will be putting a list of all of the incomes & expenses on a given day with the ability to select the day that's being viewed at the top and the total at the bottom.");

            Spacer()
        }
        .padding()
        .navigationTitle("List Overview")
    }
}

#Preview {
    NavigationStack { ListOverviewView() }
}
