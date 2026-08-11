//
//  ContentView.swift
//  watch-zone Watch App
//
//  Created by Darren DeLitizia on 8/9/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = HeartRateMonitor()
    @AppStorage("lowerLimit") private var lowerLimit = 120
    @AppStorage("upperLimit") private var upperLimit = 150
    @State private var showSettings = false
    @State private var countdownRemaining: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var showStart = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                    Text("Zone \(lowerLimit) – \(upperLimit)").font(.system(size: 16, weight: .bold))
                }
                .font(.footnote)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Spacer()

            Text(primaryText)
                .font(.system(size: showStart ? 64 : 56, weight: .bold, design: .rounded))
                .foregroundStyle(primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(primaryColor)

            Spacer()

            controls
        }
        .padding()
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            monitor.requestAuthorization()
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }

    private func beginTraining() {
        guard monitor.state == .idle else { return }
        countdownTask?.cancel()
        countdownRemaining = 3
        countdownTask = Task {
            while let remaining = countdownRemaining, remaining > 0 {
                TonePlayer.shared.playCountdownTick()
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, countdownRemaining != nil else { return }
                let next = remaining - 1
                guard next > 0 else { break }
                countdownRemaining = next
            }
            guard !Task.isCancelled, countdownRemaining != nil else { return }
            await monitor.start()
            showStart = true
            TonePlayer.shared.playStartBeep()
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            showStart = false
            countdownRemaining = nil
        }
    }

    private func cancelTraining() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = nil
        showStart = false
    }

    @ViewBuilder
    private var controls: some View {
        if isCountingDown {
            Button {
                cancelTraining()
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else if monitor.state == .idle {
            Button {
                beginTraining()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        } else {
            HStack(spacing: 12) {
                Button {
                    monitor.togglePause()
                } label: {
                    Image(systemName: monitor.state == .running ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button {
                    monitor.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    private var isCountingDown: Bool {
        countdownRemaining != nil
    }

    private var primaryText: String {
        if showStart { return "START" }
        if let countdownRemaining {
            return "\(countdownRemaining)"
        }
        return hrText
    }

    private var primaryColor: Color {
        if showStart { return .green }
        if isCountingDown { return .orange }
        return zoneColor
    }

    private var statusText: String {
        if showStart { return "Go!" }
        if isCountingDown { return "Get Ready" }
        switch monitor.state {
        case .idle:
            return "Press Start to train"
        case .paused:
            return "Paused"
        case .running:
            guard monitor.heartRate != nil else { return "Measuring…" }
            switch monitor.zone {
            case .inZone:
                return "In Zone"
            case .above:
                return "Above Zone"
            case .below:
                return "Below Zone"
            case nil:
                return "Measuring…"
            }
        }
    }

    private var hrText: String {
        guard monitor.state != .idle, let heartRate = monitor.heartRate else {
            return "––"
        }
        return "\(Int(heartRate.rounded()))"
    }

    private var zoneColor: Color {
        switch monitor.zone {
        case .inZone:
            return .green
        case .above, .below:
            return .red
        case nil:
            return .primary
        }
    }
}

#Preview {
    ContentView()
}
