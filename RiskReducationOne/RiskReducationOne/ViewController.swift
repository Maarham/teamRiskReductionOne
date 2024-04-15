//
//  ViewController.swift
//  RiskReductionOne
//
//  Created by Aman Arham on 3/12/24.
//

import UIKit
import AVFoundation

// Extension to UIColor to support hex strings
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0
                    
                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }
        
        return nil
    }
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVAudioRecorderDelegate {


    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "EchoRoute"
        label.backgroundColor = .systemRed
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let recordButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .red
        button.setTitle("Record", for: .normal)
        return button
    }()
    
    private let feedbackButton: UIButton = {
        let button = UIButton()
        let feedbackButtonColor = UIColor(hex: "#FFC7C2")
        button.backgroundColor = feedbackButtonColor
        button.setTitle("Feedback", for: .normal)
        return button
    }()
    
    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var audioRecorder: AVAudioRecorder?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUserInterface()
        checkCameraPermissions()
        setupCameraPreview()
        setupAudioRecorder()
    }
    
    func setupUserInterface() {
        view.addSubview(titleLabel)
        view.addSubview(recordButton)
        view.addSubview(feedbackButton)
        
        recordButton.addTarget(self, action: #selector(recordButtonPressed), for: .touchDown)
        recordButton.addTarget(self, action: #selector(recordButtonReleased), for: .touchUpInside)
        
        feedbackButton.addTarget(self, action: #selector(feedbackButtonPressed), for: .touchDown)
        feedbackButton.addTarget(self, action: #selector(feedbackButtonReleased), for: .touchUpInside)
    }

    
    @objc func didTapAudioButton() {
        // Toggle audio playback
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            audioPlayer?.currentTime = 0  // Optionally reset the audio to the start
        } else {
            audioPlayer?.play()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let buttonWidth = view.frame.size.width/2
        let videoLayerHeight = view.frame.size.height - titleLabel.frame.height - 525 - view.safeAreaInsets.bottom
        let buttonHeight = view.frame.size.height - 100 - videoLayerHeight
        titleLabel.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 100)
//        recordButton.frame = CGRect(x: 30, y: view.frame.size.height - 150 - view.safeAreaInsets.bottom, width: buttonWidth, height: 55)
//        feedbackButton.frame = CGRect(x: recordButton.frame.maxX + 30, y: view.frame.size.height - 150 - view.safeAreaInsets.bottom, width: buttonWidth, height: 55)
        
        feedbackButton.frame = CGRect(x: 0,
                                        y: 100 + videoLayerHeight, // Position the button at the bottom of the screen
                                        width: buttonWidth,
                                        height: buttonHeight) // Height is constant
        recordButton.frame = CGRect(x: buttonWidth, // Positioned right after the recordButton
                                          y: 100 + videoLayerHeight, // Align with recordButton at the bottom
                                          width: buttonWidth,
                                          height: buttonHeight)
        
        videoPreviewLayer?.frame = CGRect(x: 0, y: titleLabel.frame.maxY, width: view.frame.size.width, height: videoLayerHeight)
    }
    
    func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            self.setupCameraPreview()
            
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCameraPreview()
                    }
                }
            }
            
        case .denied: // The user has previously denied access.
            return // Perhaps, show an alert to the user to enable it from settings.
            
        case .restricted: // The user can't grant access due to restrictions.
            return
            
        @unknown default:
            fatalError()
        }
    }
    
    func setupCameraPreview() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            print("Unable to access back camera")
            return
        }
        
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        else { print("Unable to add back camera to capture session") }
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.frame = view.layer.bounds
        videoPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(videoPreviewLayer, at: 0)
        
        // Start the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    @objc func recordButtonPressed() {
        startRecording()
    }

    @objc func recordButtonReleased() {
        stopRecording()
    }
    
    @objc func feedbackButtonPressed() {
        startRecording()
    }

    @objc func feedbackButtonReleased() {
        stopRecording()
    }
    
    func setupAudioRecorder() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
        } catch {
            print("Could not set up the audio recorder: \(error)")
        }
    }

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            audioRecorder?.record()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("Failed to stop recording: \(error)")
        }
    }
    
    // This function will return the URL to the documents directory of the app.
    // It's used to store the recorded audio file.
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
