import SwiftUI

struct AddItemView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome. This is the page where you can add a new expense / income.")
                .foregroundStyle(.secondary)
            
            Text("Nobodies on this yet, this will be started later. Eventually, you should be able to input a time frame (e.g. one-time / weekly / monthly / yearly), and an amount (e.g. -10£, +200£) to create a new item.");

            Spacer()
        }
        .padding()
        .navigationTitle("Add Item")
    }
}

#Preview {
    NavigationStack { AddItemView() }
}
