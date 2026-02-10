import SwiftUI

struct ItemEditorView: View {
    
    let item: DayLineItem
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            Text("DEBUG")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("ID: \(item.id.uuidString)")
            Text("Title: \(item.title)")
            Text(item.amount, format: .currency(code: "GBP"))

            Spacer()
        }
        .padding()
    }
}

#Preview {
    NavigationStack { HomeView() }
}
