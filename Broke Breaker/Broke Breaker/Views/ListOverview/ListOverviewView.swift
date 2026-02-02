import SwiftUI
import SwiftData

struct ListOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var color: Color = .blue
    @State private var date = Date.now
    @State private var itemsForSelectedDay: [Item] = []
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
            // The list
            if itemsForSelectedDay.isEmpty {
                ContentUnavailableView("No items for this date", systemImage: "tray")
            } else {
                List(itemsForSelectedDay, id: \.self) { item in
                    HStack {
                        Text(item.timestamp, style: .time)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 250)
            }
        }
        .padding()
        .navigationTitle("List Overview")
        
        // When is first loaded
        .onAppear {
            weekStart = Calendar.current.date(from:
                Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            ) ?? weekStart
            fetchItems()
        }
        
        // When the week is changed in the date picker
        .onChange(of: date) { _, newValue in
            weekStart = Calendar.current.date(from:
                Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newValue)
            ) ?? weekStart
            fetchItems()
        }
    }

    private func fetchItems() {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        let predicate = #Predicate<Item> { item in
            item.timestamp >= start && item.timestamp < end
        }

        let descriptor = FetchDescriptor<Item>(predicate: predicate,
                                                 sortBy: [SortDescriptor<Item>(\.timestamp, order: .forward)])
        do {
            itemsForSelectedDay = try modelContext.fetch(descriptor)
        } catch {
            itemsForSelectedDay = []
        }
    }
    
    private func today() {
        date = Date.now
    }
}
// Text("This is where Calum will be putting a list of all of the incomes & expenses on a given day with the ability to select the day that's being viewed at the top and the total at the bottom.");

