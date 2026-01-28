import SwiftUI

struct ListOverviewView: View {
    @State private var color: Color = .blue
    @State private var date = Date.now
    let colums = Array(repeating: GridItem(.flexible()), count: 7)
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome. This is the list overview page.")
                .foregroundStyle(.secondary)
            
            // The date picker
            LabeledContent("Date") {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
            // The calander
            LazyVGrid(columns: colums) {
                let days: [Date] = (0..<7).compactMap {
                    Calendar.current.date(byAdding: .day, value: $0, to: date)
                }
                ForEach(days, id: \.timeIntervalSince1970) { day in
                    Text(day.formatted(.dateTime.day()))
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Circle()
                                .foregroundStyle(color.opacity(0.3))
                        )
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("List Overview")
    }
}


// Text("This is where Calum will be putting a list of all of the incomes & expenses on a given day with the ability to select the day that's being viewed at the top and the total at the bottom.");
