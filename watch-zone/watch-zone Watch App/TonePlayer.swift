//
//  TonePlayer.swift
//  watch-zone Watch App
//
//  Created by Darren DeLitizia on 8/9/26.
//

import AVFoundation
import Foundation

final class TonePlayer {
    static let shared = TonePlayer()

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var phase: Double = 0
    private var isPlaying = false
    private var playID = 0

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func playHighBeep() {
        playHighBeepRepeated(times: 1)
    }

    func playHighBeepRepeated(times: Int = 2) {
        playRepeated(frequency: 2000, duration: 0.5, times: times)
    }

    func playLowBeep() {
        play(frequency: 1000, duration: 1.0)
    }

    func playCountdownTick() {
        play(frequency: 880, duration: 0.2)
    }

    func playStartBeep() {
        play(frequency: 1800, duration: 1.5)
    }

    private let repeatGap = 0.2

    func playRepeated(frequency: Double, duration: Double, times: Int) {
        guard times > 0 else { return }
        play(frequency: frequency, duration: duration)
        guard times > 1 else { return }
        let interval = duration + repeatGap
        for index in 1..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(index)) { [weak self] in
                self?.play(frequency: frequency, duration: duration)
            }
        }
    }

    func play(frequency: Double, duration: Double) {
        stop()

        let id = playID + 1
        playID = id

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0 else { return }

        phase = 0
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)
            for frame in 0..<frames {
                let value = Float(sin(self.phase)) * 0.4
                self.phase += 2.0 * Double.pi * frequency / sampleRate
                for buffer in buffers {
                    let samples = buffer.mData?.assumingMemoryBound(to: Float.self)
                    samples?[frame] = value
                }
            }
            return noErr
        }

        engine.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            print("TonePlayer: failed to start engine: \(error)")
            engine.detach(node)
            return
        }

        self.node = node
        isPlaying = true

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.playID == id else { return }
            self.stop()
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        if let node {
            engine.detach(node)
        }
        node = nil
        isPlaying = false
    }
}
