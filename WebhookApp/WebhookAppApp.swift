import SwiftUI
class AppViewModel: ObservableObject {
    @Published var zipCode: String = ""
    @Published var showKPTextBlock: Bool = false
    @Published var temperatures: [TemperatureRecord] = []
    @Published var isLoading = false
    @Published var temperatureColorPreference = TemperatureColorPreference()
    @Published var reminderTime: Date {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(reminderTime, forKey: "reminderTime")
            scheduleReminder()
        }
    }
    
    init() {
        let defaults = UserDefaults.standard
        reminderTime = defaults.object(forKey: "reminderTime") as? Date ?? Date()
        // Existing initialization...
    }
    struct TemperatureColorPreference {
        var ranges: [TemperatureRange] = []
    }
    struct TemperatureRange: Identifiable {
        var id = UUID()
        var lowerBound: Double
        var upperBound: Double
        var color: Color
    }
    
    func backgroundColor(for temperature: Double) -> Color {
        for range in temperatureColorPreference.ranges {
            if temperature >= range.lowerBound && temperature < range.upperBound {
                return range.color
            }
        }
        return .white // Default color if no range matches
    }
    
    func fetchTemperatures() {
        isLoading = true
        TemperatureService.shared.fetchTemperatures(forZip: zipCode) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let records):
                    self?.temperatures = records
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }
    }

    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Blanket Reminder"
        content.body = "Don't forget to do a row of your blanket today!"
        content.sound = UNNotificationSound.default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "blanketReminder", content: content, trigger: trigger)
        
        center.add(request) { (error) in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}


extension AppViewModel {
    func formatDate(_ dateString: String) -> String {
        guard let date = DateFormatter.yearMonthDay.date(from: dateString) else { return dateString }
        return DateFormatter.monthDayOrdinal.string(from: date)
    }
    
    func letterForDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return "" }
    
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date)
        return (dayOfYear ?? 0) % 2 == 0 ? "P" : "K"
    }
}

struct TemperatureRecordsView: View {
    @ObservedObject var viewModel: AppViewModel
    let temperatureColorPreference: AppViewModel.TemperatureColorPreference
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.temperatures.isEmpty {
                    Section {
                        Text("Please configure your Zip Code in Settings Tab.")
                            .foregroundColor(.gray)
                    }
                } else {
                    if let mostRecentRecord = viewModel.temperatures.last {
                        Section(header: Text("Today")) {
                            temperatureCard(for: mostRecentRecord)
                        }
                    }
                    
                    Section(header: Text("Historical Temperatures")) {
                        ForEach(viewModel.temperatures, id: \.id) { record in
                            temperatureRow(for: record)
                        }
                    }
                }
            }
            .navigationTitle("BlanketBuddy")
        }
        .onAppear {
            viewModel.fetchTemperatures()
        }
    }
    
    private func temperatureCard(for record: TemperatureRecord) -> some View {
        HStack {
            Image(systemName: "thermometer")
                .foregroundColor(viewModel.backgroundColor(for: record.temp)) // Change color based on temperature
                .scaledToFit()
            VStack(alignment: .leading) {
                HStack {
                    if viewModel.showKPTextBlock {
                        Text(viewModel.letterForDate(record.datetime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.trailing, 4)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Text(viewModel.formatDate(record.datetime))
                        .font(.headline)
                }
                Text("\(record.temp, specifier: "%.1f")°F")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity) // Fill the VStack horizontally
            .frame(maxHeight: .infinity)
            .padding()
        }
    }
    private func temperatureRow(for record: TemperatureRecord) -> some View {
        HStack {
            if viewModel.showKPTextBlock {
                Text(viewModel.letterForDate(record.datetime))
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.trailing, 4)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            Text(viewModel.formatDate(record.datetime))
                .font(.body)
            
            Spacer()
            
            Text("\(record.temp, specifier: "%.1f")°F")
                .fontWeight(.bold)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(viewModel.backgroundColor(for: record.temp)))
        }
    }
}
    
    struct SettingsView: View {
        @ObservedObject var viewModel: AppViewModel
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Location Settings")) {
                        TextField("Zip Code", text: $viewModel.zipCode)
                            .keyboardType(.numberPad)
                        
                        Button("Refresh") {
                            viewModel.fetchTemperatures()
                        }
                    }
                    
                    Section(header: Text("Temperature Color Ranges")) {
                        ForEach($viewModel.temperatureColorPreference.ranges) { $range in
                            HStack {
                                TextField("Lower Bound", value: $range.lowerBound, formatter: NumberFormatter())
                                TextField("Upper Bound", value: $range.upperBound, formatter: NumberFormatter())
                                ColorPicker("", selection: $range.color)
                            }
                        }
                        .onDelete(perform: deleteRange)
                        .onMove(perform: moveRange)
                        
                        Button("Add Range") {
                            withAnimation {
                                viewModel.temperatureColorPreference.ranges.append(AppViewModel.TemperatureRange(lowerBound: 0, upperBound: 10, color: .white))
                            }
                        }
                    }
                    
                    Section(header: Text("Knitting Settings")) {
                        Toggle("Show Knit/Pearl Suggestions", isOn: $viewModel.showKPTextBlock)
                    }
                    
                    Section(header: Text("Notification Settings")) {
                        DatePicker("Reminder Time", selection: $viewModel.reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: viewModel.reminderTime) { newValue in
                                viewModel.scheduleReminder()
                            }
                        Button("Request Push Notifications") {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                                if success {
                                    print("All set!")
                                } else if let error {
                                    print(error.localizedDescription)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Settings")
                .toolbar {
                    EditButton()
                }
            }
        }
        
        private func deleteRange(at offsets: IndexSet) {
            viewModel.temperatureColorPreference.ranges.remove(atOffsets: offsets)
        }
        
        private func moveRange(from source: IndexSet, to destination: Int) {
            viewModel.temperatureColorPreference.ranges.move(fromOffsets: source, toOffset: destination)
        }
    }

struct TemperatureQuiltView: View {
    let temperatureColorPreference: AppViewModel.TemperatureColorPreference
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack {
                ForEach(viewModel.temperatures, id: \.id) { record in
                    Rectangle()
                        .fill(viewModel.backgroundColor(for: record.temp))
                        .frame(height: 20)
                }
            }
        }
        .navigationTitle("Temperature Blanket")
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        TabView {
            TemperatureRecordsView(viewModel: viewModel, temperatureColorPreference: viewModel.temperatureColorPreference)
                .tabItem {
                    Label("Temps", systemImage: "thermometer")
                }
            SettingsView(viewModel: viewModel)
                .tabItem {
                Label("Settings", systemImage: "gear")
                }
            TemperatureQuiltView(temperatureColorPreference: viewModel.temperatureColorPreference, viewModel: viewModel) // New tab for Temperature Quilt
                .tabItem {
                    Label("Blanket", systemImage: "square.fill")
                }
            }
    }
}
    
    struct TemperatureRecord: Decodable, Identifiable {
        var id: Int
        var zip: Int
        var datetime: String
        var temp: Double
        
        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case zip
            case datetime
            case temp
        }
    }


extension DateFormatter {
    static let yearMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let monthDayOrdinal: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()
}

extension NumberFormatter {
    static let ordinal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()
}

@main
struct WebhookApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
