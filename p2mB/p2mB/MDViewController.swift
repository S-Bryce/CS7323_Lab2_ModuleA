//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//
import UIKit
import Metal

class MDViewController: UIViewController, AudioModelDelegate {
    
    @IBOutlet weak var decibelLabel: UILabel!
    @IBOutlet weak var userView: UIView!
    @IBOutlet weak var gestureDirectionLabel: UILabel!
    
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 16
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        audio.delegate = self
        
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            graph.addGraph(withName: "fft", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            graph.addGraph(withName: "time", numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            graph.makeGrids()
        }
        
        audio.startMicrophoneProcessing(withFps: 5)
        audio.play()
    }
    
    // MARK: AudioModelDelegate Methods
    
    func updateGraphs(fftData: [Float], timeData: [Float]) {
        if let graph = self.graph {
            graph.updateGraph(data: fftData, forKey: "fft")
            graph.updateGraph(data: timeData, forKey: "time")
        }
    }
    
    func updateDecibelLevel(dB: Float) {
        decibelLabel.text = String(format: "%.2f dB", dB)
    }
    
    // New delegate method to reflect gesture detection updates
    func updateGestureDirection(direction: String) {
        gestureDirectionLabel.text = direction
    }
}

