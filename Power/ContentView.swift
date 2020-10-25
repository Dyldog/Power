//
//  ContentView.swift
//  Power
//
//  Created by Dylan Elliott on 23/10/20.
//

import SwiftUI
import AVFoundation

extension Date {
    func timeSince(_ date: Date) -> (minutes: Int, seconds: Int) {
        let interval = Int(self.timeIntervalSince(date))
        let seconds = interval % 60
        let minutes = (interval - seconds) / 60
        return (minutes, seconds)
    }
}

class ViewModel: ObservableObject {
    private let totalDrinks: Int = 60
    
    let startDate: Date
    
    @Published var backgroundColor: UIColor = .niceRandomColor()
    var lastMins: Int
    @Published var clock: Int = 0
    
    
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
    
    init() {
        if let savedDate = UserDefaults.standard.value(forKey: "DATE") as? Date {
            startDate = savedDate
        } else {
            startDate = Date()
            UserDefaults.standard.setValue(startDate, forKey: "DATE")
        }
        
        let timeSince = Date().timeSince(startDate)
        lastMins = timeSince.minutes
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in self.timer() })
        playSound()
    }
    
    func timer() {
        let timeSince = Date().timeSince(startDate)
        if timeSince.minutes != lastMins {
            backgroundColor = .niceRandomColor()
            lastMins = timeSince.minutes
            playSound()
        }
        
        clock += 1
    }

    var player: AVAudioPlayer?

    func playSound() {
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
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ViewModel = .init()
    
    var body: some View {
        ZStack {
            Color(viewModel.backgroundColor).ignoresSafeArea()
            VStack(spacing: 20) {
                VStack {
                    Text("Total Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.totalTime)
                        .font(.title)
                }
                VStack {
                    Text("Time To Next Drink")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.timeToNextDrink)
                        .font(.system(size: 128))
                }
                VStack {
                    Text("Drinks Remaining")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.drinksRemaining)
                        .font(.title)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
