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
    func updatePeaks(highestFreq: Float, secondHighestFreq: Float)
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
            
            for slice in stride(from: 0, to: fftData.count-1, by: BATCH_SIZE) {
                let temp = Array(fftData[slice...min(slice+BATCH_SIZE-1, fftData.count - 1)])
                
                highest_local_idx = 0
                for (index, value) in temp.enumerated() {
                    if value > temp[highest_local_idx] {
                        highest_local_idx = index
                    }
                }
                highest_local_idx = highest_local_idx + slice
                
                if fftData[highest_local_idx] > first_highest_vol {
                    first_highest_vol = fftData[highest_local_idx]
                    highest_global_idx = highest_local_idx
                } else if fftData[highest_local_idx] > second_highest_vol && highest_global_idx != highest_local_idx{
                    second_highest_vol = fftData[highest_local_idx]
                    second_highest_global_idx = highest_local_idx
                }
            }
            
            // Notify the delegate (GraphController) with the updated data
            delegate?.updateGraphs(fftData: fftData, timeData: timeData)
            delegate?.updatePeaks(highestFreq: Float((highest_global_idx + (highest_global_idx/2)) * (22050/8192)) * 0.98, secondHighestFreq: Float((second_highest_global_idx + (second_highest_global_idx/2)) * (22050/8192)) * 0.98)
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
}
