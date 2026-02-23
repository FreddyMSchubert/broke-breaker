import SwiftUI

struct AddItemView: View {
    var body: some View {
        TransactionEditorView(mode: .create)
    }
}

#Preview { RootTabView() }
