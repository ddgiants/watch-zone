//
//  HeartRateMonitor.swift
//  watch-zone Watch App
//
//  Created by Darren DeLitizia on 8/9/26.
//

import Combine
import Foundation
import HealthKit

@MainActor
final class HeartRateMonitor: NSObject, ObservableObject {
    @Published var state: TrainingState = .idle
    @Published var heartRate: Double?
    @Published var zone: ZoneState?

    private let healthStore = HKHealthStore()
    private let heartRateType: HKQuantityType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let workoutType: HKSampleType = HKObjectType.workoutType()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var pollTask: Task<Void, Never>?
    private let tonePlayer = TonePlayer.shared

    // MARK: - Authorization

    func requestAuthorization() {
        healthStore.requestAuthorization(toShare: [workoutType], read: [heartRateType]) { _, error in
            if let error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Session control

    func start() async {
        guard state == .idle else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            self.session = session
            self.builder = builder

            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())

            state = .running
            zone = nil
            heartRate = nil
            startPolling()
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }

    func pause() {
        guard state == .running else { return }
        session?.pause()
        stopPolling()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        session?.resume()
        state = .running
        startPolling()
    }

    func togglePause() {
        switch state {
        case .running:
            pause()
        case .paused:
            resume()
        case .idle:
            break
        }
    }

    func stop() {
        guard state != .idle else { return }
        stopPolling()
        let builder = self.builder
        let session = self.session
        session?.end()
        Task {
            do {
                try await builder?.endCollection(at: Date())
                _ = try? await builder?.finishWorkout()
            } catch {
                print("Failed to end workout collection: \(error.localizedDescription)")
            }
        }
        self.session = nil
        self.builder = nil
        heartRate = nil
        zone = nil
        state = .idle
    }

    // MARK: - Heart rate polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.readHeartRate()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func readHeartRate() {
        guard let builder,
              let statistics = builder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity() else {
            return
        }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        heartRate = bpm
        updateZone(with: bpm)
    }

    private func updateZone(with bpm: Double) {
        let limits = self.limits
        let newZone: ZoneState
        if bpm < Double(limits.lower) {
            newZone = .below
        } else if bpm > Double(limits.upper) {
            newZone = .above
        } else {
            newZone = .inZone
        }

        guard zone != newZone else { return }

        let hadPreviousReading = zone != nil
        zone = newZone

        guard hadPreviousReading else { return }
        switch newZone {
        case .inZone:
            tonePlayer.playLowBeep()
        case .above, .below:
            tonePlayer.playHighBeepRepeated()
        }
    }

    private var limits: (lower: Int, upper: Int) {
        let defaults = UserDefaults.standard
        let lower = defaults.object(forKey: "lowerLimit") as? Int ?? 120
        let upper = defaults.object(forKey: "upperLimit") as? Int ?? 150
        return (lower, upper)
    }

    private func resetToIdle() {
        stopPolling()
        heartRate = nil
        zone = nil
        state = .idle
    }
}

extension HeartRateMonitor: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch toState {
            case .paused:
                self.stopPolling()
                self.state = .paused
            case .ended, .notStarted:
                self.resetToIdle()
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.resetToIdle()
        }
    }
}

enum TrainingState: Equatable {
    case idle
    case running
    case paused
}

enum ZoneState: Equatable {
    case inZone
    case above
    case below
}
