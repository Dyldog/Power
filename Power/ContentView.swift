//
//  ContentView.swift
//  Power
//
//  Created by Dylan Elliott on 23/10/20.
//

import SwiftUI
import AVFoundation
import UserNotifications

extension Date {
    func timeSince(_ date: Date) -> (minutes: Int, seconds: Int) {
        let interval = Int(self.timeIntervalSince(date))
        let seconds = interval % 60
        let minutes = (interval - seconds) / 60
        return (minutes, seconds)
    }
}

struct PowerData {
    let startDate: Date
    let totalDrinks: Int
    
    var completedMinutes: Int { Date().timeSince(startDate).minutes }
    var isEnded: Bool { completedMinutes >= totalDrinks }
    
    var totalTime: String {
        let timeSince = Date().timeSince(startDate)
        return "\(timeSince.minutes):\(String(timeSince.seconds).leftPadding(toLength: 2, withPad: "0"))"
    }
    
    var drinksRemaining: String {
        let timeSince = Date().timeSince(startDate)
        return "\(totalDrinks - timeSince.minutes)"
    }
    
    var timeToNextDrink: String {
        let timeSince = Date().timeSince(startDate)
        return "\(60 - timeSince.seconds)"
    }
}

class ViewModel: ObservableObject {
    enum State {
        case showWarning
        case beforeStart
        case started(Date, Int, Int)
        case ended
    }
    
    private let totalDrinks: Int = 60
    private var player: AVAudioPlayer?
    
    @Published var backgroundColor: UIColor = .niceRandomColor()
    @Published var clock: Int = 0
    
    var state: State = .showWarning {
        didSet { backgroundColor = .niceRandomColor() }
    }
    
    
    init() {
        var id = UIBackgroundTaskIdentifier.invalid
        id = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(id)
        })
    }
    func didTapWarning() {
        UserDefaults.standard.setValue(nil, forKey: "DATE")
        if let savedDate = UserDefaults.standard.value(forKey: "DATE") as? Date {
            start(date: savedDate)
        } else {
            state = .beforeStart
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        notificationCenter.requestAuthorization(options: options) {
            (didAllow, error) in
            if !didAllow {
                print("User has declined notifications")
            }
        }
    }
    
    func start(date: Date = Date()) {
        UserDefaults.standard.setValue(date, forKey: "DATE")
        backgroundColor = .niceRandomColor()
        state = .started(date, totalDrinks, -1)
        timer()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in self.timer() })
    }
    
    func timer() {
        guard case let .started(date, drinks, lastUpdate) = state else { return }
        let currentData = PowerData(startDate: date, totalDrinks: drinks)
        
        if currentData.isEnded {
            state = .ended
            UserDefaults.standard.setValue(nil, forKey: "DATE")
            playSound(currentData)
            UIApplication.shared.applicationIconBadgeNumber = 0
        } else if currentData.completedMinutes != lastUpdate {
            playSound(currentData)
            state = .started(date, totalDrinks, currentData.completedMinutes)
            UIApplication.shared.applicationIconBadgeNumber = Int(currentData.drinksRemaining)! 
        } else {
            clock += 1
        }
    }

    

    private func playSound(_ data: PowerData) {
        guard let url = Bundle.main.url(forResource: "sound", withExtension: "mp3") else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)

            /* iOS 10 and earlier require the following line:
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */

            guard let player = player else { return }
            player.volume = 0.5

            player.play()

        } catch let error {
            print(error.localizedDescription)
        }
        
        scheduleNotification(data: data)
    }
    
    func scheduleNotification(data: PowerData) {
        let content = UNMutableNotificationContent()
        content.title = "Drink!"
        content.body = "\(data.drinksRemaining) drinks to go"
        content.sound = UNNotificationSound.defaultCritical //.init(named: "sound")
        content.badge = Int(data.drinksRemaining)! as NSNumber
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: "NOTIFICATION", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
         
    }
}

extension Button {
    func styled() -> some View {
        return self
            .background(Color.black)
            .cornerRadius(10)
            .padding()
    }
}
struct ContentView: View {
    @ObservedObject var viewModel: ViewModel = .init()
    
    var body: some View {
        ZStack {
            let mainColor = Color(viewModel.backgroundColor)
            mainColor.ignoresSafeArea()
            switch viewModel.state {
            case .showWarning:
                Button(action: { viewModel.didTapWarning() }) {
                    Text("Please eat responsibly and do not use food in excess")
                        .font(.title)
                        .foregroundColor(mainColor)
                        .multilineTextAlignment(.center)
                        .padding()
                }.styled()
            case .beforeStart:
                Button(action: { viewModel.start() }) {
                    Text("Start")
                        .font(.title)
                        .foregroundColor(mainColor)
                        .padding()
                }.styled()
            case let .started(startDate, drinks, _):
                let model = PowerData(startDate: startDate, totalDrinks: drinks)
                HStack {
                    VStack(spacing: 20) {
                        VStack {
                            Text("Total Time")
                                .font(.subheadline)
                                .foregroundColor(mainColor)
                            Text(model.totalTime)
                                .font(.title)
                                .foregroundColor(mainColor)
                        }
                        VStack {
                            Text("Time To Next Bite")
                                .font(.subheadline)
                                .foregroundColor(mainColor)
                            Text(model.timeToNextDrink)
                                .font(.system(size: 128))
                                .foregroundColor(mainColor)
                        }
                        VStack {
                            Text("Bite Remaining")
                                .font(.subheadline)
                                .foregroundColor(mainColor)
                            Text(model.drinksRemaining)
                                .font(.title)
                                .foregroundColor(mainColor)
                        }
                    }
                    .frame(width: 200)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
                }
                
            case .ended:
                Button(action: { viewModel.start() }) {
                    Text("Restart")
                        .font(.title)
                        .foregroundColor(mainColor)
                        .padding()
                }.styled()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
