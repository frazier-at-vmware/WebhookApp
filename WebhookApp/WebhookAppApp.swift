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
        var zeroToTen: Color = .gray
        var tenToTwenty: Color = .mint
        var twentyToThirty: Color = .blue
        var thirtyToForty: Color = .cyan
        var fortyToFifty: Color = .green
        var fiftyToSixty: Color = .yellow
        var sixtyToSeventy: Color = .orange
        var seventyToEighty: Color = .pink
        var eightyToNinety: Color = .red
        var ninetyToHundred: Color = .purple
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
    
    
    func backgroundColor(for temperature: Double) -> Color {
        switch temperature {
        case 0..<10: return temperatureColorPreference.zeroToTen
        case 10..<20: return temperatureColorPreference.tenToTwenty
        case 20..<30: return temperatureColorPreference.twentyToThirty
        case 30..<40: return temperatureColorPreference.thirtyToForty
        case 40..<50: return temperatureColorPreference.fortyToFifty
        case 50..<60: return temperatureColorPreference.fiftyToSixty
        case 60..<70: return temperatureColorPreference.sixtyToSeventy
        case 70..<80: return temperatureColorPreference.seventyToEighty
        case 80..<90: return temperatureColorPreference.eightyToNinety
        case 90..<120: return temperatureColorPreference.ninetyToHundred
        default: return .white
        }
    }
    var body: some View {
        NavigationView {
            List {
                if let mostRecentRecord = viewModel.temperatures.last {
                    Section(header: Text("Latest")) {
                        temperatureCard(for: mostRecentRecord)
                    }
                }
                
                Section(header: Text("History")) {
                    ForEach(viewModel.temperatures, id: \.id) { record in
                        temperatureRow(for: record)
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
        VStack(alignment: .leading) {
            Text(viewModel.formatDate(record.datetime))
                .font(.headline)
            Text("\(record.temp, specifier: "%.1f")°F")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity) // Fill the VStack horizontally
        .frame(maxHeight: .infinity)
        .padding()
        .background(Color(backgroundColor(for: record.temp)))
  
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
                .background(RoundedRectangle(cornerRadius: 10).fill(backgroundColor(for: record.temp)))
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
                Section(header: Text("Color Settings for Temperatures")) {
                    ColorPicker("0-9", selection: $viewModel.temperatureColorPreference.zeroToTen)
                    ColorPicker("10-19", selection: $viewModel.temperatureColorPreference.tenToTwenty)
                    ColorPicker("20-29", selection: $viewModel.temperatureColorPreference.twentyToThirty)
                    ColorPicker("30-39", selection: $viewModel.temperatureColorPreference.thirtyToForty)
                    ColorPicker("40-49", selection: $viewModel.temperatureColorPreference.fortyToFifty)
                    ColorPicker("50-59", selection: $viewModel.temperatureColorPreference.fiftyToSixty)
                    ColorPicker("60-69", selection: $viewModel.temperatureColorPreference.sixtyToSeventy)
                    ColorPicker("70-79", selection: $viewModel.temperatureColorPreference.seventyToEighty)
                    ColorPicker("80-89", selection: $viewModel.temperatureColorPreference.eightyToNinety)
                    ColorPicker("90-100+", selection: $viewModel.temperatureColorPreference.ninetyToHundred)
                
                }
                Section(header: Text("Display Settings")) {
                    Toggle("Show K/P Text Block", isOn: $viewModel.showKPTextBlock)
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
                    Button("Schedule Notification") {
                        let content = UNMutableNotificationContent()
                        content.title = "Knit Your Row"
                        content.subtitle = "A row a day keeps the doctor away."
                        content.sound = UNNotificationSound.default

                        // show this notification five seconds from now
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

                        // choose a random identifier
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

                        // add our notification request
                        UNUserNotificationCenter.current().add(request)
                    }

                }
            }
            }
            .navigationTitle("Settings")
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
