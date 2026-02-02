import SwiftUI
import SwiftData

struct ListOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var color: Color = .blue
    @State private var date = Date.now
    @State private var weekStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    let colums = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome. This is the list overview page.")
                .foregroundStyle(.secondary)
            
            HStack (){
                // the date picker
                DatePicker("", selection: $date, displayedComponents: .date)
                // today button
                Button(action: today) {
                    Text("Today")
                        .foregroundColor(.black)
                } .buttonStyle(.bordered)
            }
            
            // The calander
            HStack{
                let days: [Date] = (0..<7).compactMap {
                    Calendar.current.date(byAdding: .day, value: $0, to: weekStart)
                }
                let daysLetters = ["M", "T", "W", "T", "F", "S", "S"]
                ForEach(days.indices, id: \.self) { index in
                    let day = days[index]
                    VStack(spacing: 6) {
                        // The week letter
                        Text(daysLetters[index])
                            .foregroundStyle(.secondary)
                            .font(.caption.bold())
                        // The day number
                        Text(day.formatted(.dateTime.day()))
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                Circle()
                                    .foregroundStyle(
                                        Calendar.current.isDate(day, inSameDayAs: date)
                                        ? Color.orange
                                        : color.opacity(0.3)
                                    )
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        date = day
                    }
                }
            }
        }
        .padding()
        .navigationTitle("List Overview")
        
        // When is first loaded
        .onAppear {
            weekStart = Calendar.current.date(from:
                Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            ) ?? weekStart
        }
        
        // When the week is changed in the date picker
        .onChange(of: date) { _, newValue in
            weekStart = Calendar.current.date(from:
                Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newValue)
            ) ?? weekStart
        }
    }

    private func today() {
        date = Date.now
    }
}
// Text("This is where Calum will be putting a list of all of the incomes & expenses on a given day with the ability to select the day that's being viewed at the top and the total at the bottom.");
