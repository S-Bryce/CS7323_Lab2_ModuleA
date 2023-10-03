//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal

class GraphController: UIViewController, AudioModelDelegate {
    
    @IBOutlet weak var peak1st: UILabel!
    @IBOutlet weak var peak2nd: UILabel!
    
    @IBOutlet weak var userView: UIView!
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 16
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the delegate to receive updates
        audio.delegate = self
        
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // because the fft is returned in dB which has very large negative values and some large positive values
            graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            graph.addGraph(withName: "time",
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            
            graph.makeGrids() // add grids to graph
        }
        
        // start up the audio model here, querying the microphone
        audio.startMicrophoneProcessing(withFps: 5) // preferred number of FFT calculations per second
        
        audio.play()
    }
    
    // MARK: AudioModelDelegate Methods
    
    func updateGraphs(fftData: [Float], timeData: [Float]) {
        // Update the graph with refreshed FFT Data
        if let graph = self.graph {
            graph.updateGraph(data: fftData, forKey: "fft")
            graph.updateGraph(data: timeData, forKey: "time")
        }
    }
    
    func updatePeaks(highestFreq: Float, secondHighestFreq: Float) {
        // Update the UI with the peak frequencies
        peak1st.text = String(highestFreq)
        peak2nd.text = String(secondHighestFreq)
    }
}
