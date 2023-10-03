
//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//
import Foundation
import Accelerate
import UIKit

// Protocol to define the delegate methods
protocol AudioModelDelegate: AnyObject {
    func updateGraphs(fftData: [Float], timeData: [Float])
    func updateDecibelLevel(dB: Float)
    func updateGestureDirection(direction: String)

}

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE: Int
    private var BATCH_SIZE: Int
    private var first_highest_vol: Float
    private var second_highest_vol: Float
    private var highest_local_idx: Int
    private var highest_global_idx: Int
    private var second_highest_global_idx: Int
    
    // Delegate property for communication with the controller
    weak var delegate: AudioModelDelegate?
    
    // Properties for interfacing with the API
    var timeData: [Float]
    var fftData: [Float]
    
    // MARK: Public Methods
    init(buffer_size: Int) {
        BUFFER_SIZE = buffer_size
        BATCH_SIZE = 19
        // anything not lazily instantiated should be allocated here
        timeData = Array(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array(repeating: 0.0, count: BUFFER_SIZE / 2)
        first_highest_vol = 0
        second_highest_vol = 0
        highest_local_idx = 0
        highest_global_idx = 0
        second_highest_global_idx = 0
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps: Double) {
        // setup the microphone to copy to circular buffer
        if let manager = audioManager {
            manager.inputBlock = handleMicrophone
            
            // repeat this fps times per second using the timer class
            // every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
        }
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        //self.audioManager?.outputBlock = self.handleSpeakerQueryWithSinusoid // swift for loop
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }

    // You must call this when you want the audio to start being handled by our model
    func play() {
        if let manager = audioManager {
            manager.play()
        }
    }
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager: Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper: FFTHelper? = {
        return FFTHelper(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer: CircularBuffer? = {
        return CircularBuffer(numChannels: Int64(audioManager!.numInputChannels),
                              andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval() {
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
            
            // at this point, we have saved the data to the arrays:
            // timeData: the raw audio samples
            // fftData: the FFT of those same samples
            // the user can now use these variables however they like
            
            // Calculate RMS and then convert it to dB
            let rms = sqrt(timeData.map { $0 * $0 }.reduce(0, +) / Float(timeData.count))
            let dB = 20 * log10(rms)
                    
                    // Notify the delegate with the updated data
            delegate?.updateGraphs(fftData: fftData, timeData: timeData)
            delegate?.updateDecibelLevel(dB: dB)
            
            analyzeGesture()
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            // if using swift for generating the sine wave: when changed, we need to update our increment
            //phaseIncrement = Float(2*Double.pi*sineFrequency/audioManager!.samplingRate)
            
            // if using objective c: this changes the frequency in the novocain block
            self.audioManager?.sineFrequency = sineFrequency
        }
    }
    
    var isPlaying = false

    func startAndPlay(withFreq:Float = 330.0) {
        if !isPlaying {
            startProcessingSinewaveForPlayback(withFreq: withFreq)
            play()
            isPlaying = true
        }
    }

    func stop() {
        if isPlaying {
            audioManager?.pause()
            isPlaying = false
        }
    }
    
    // We'll emit an ultrasonic frequency for Doppler detection.
    let emittedFrequency: Float = 21000.0 // 21 kHz, adjust if necessary
    var previousFrequencyPeak: Float = 0
        
    // This method calculates the dominant frequency from the FFT data.
    func dominantFrequency(from fftData: [Float]) -> Float {
        var maxMagnitude: Float = -1000.0
        var dominantFrequency: Float = 0.0
            
        for (index, magnitude) in fftData.enumerated() {
            if magnitude > maxMagnitude {
                maxMagnitude = magnitude
                dominantFrequency = Float(index) * Float(audioManager!.samplingRate) / Float(BUFFER_SIZE)
            }
        }
        return dominantFrequency
    }
        
        
        // Ensure the sine wave emitted for gesture detection is started.
    func startGestureDetection() {
        startAndPlay(withFreq: emittedFrequency)
    }
    
    func analyzeGesture() {
        let detectedFrequency = dominantFrequency(from: fftData)
        let frequencyDifference = detectedFrequency - emittedFrequency
            
        var gesture: String
        if abs(frequencyDifference) < 10 { // Tolerance of 10 Hz
            gesture = "No significant gesture detected."
        } else if frequencyDifference > 0 {
            gesture = "Gesture moving towards the device."
        } else {
            gesture = "Gesture moving away from the device."
        }
        
        delegate?.updateGestureDirection(direction: gesture)
        previousFrequencyPeak = detectedFrequency
    }

}
