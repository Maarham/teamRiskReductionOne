//
//  ViewController.swift
//  RiskReductionOne
//
//  Created by Aman Arham on 3/12/24.
//

import UIKit
import AVFoundation
import Vision

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

extension UIButton {
    func setBackgroundColor(color: UIColor, forState: UIControl.State) {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            self.setBackgroundImage(colorImage, for: forState)
        }
    }
}


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVAudioRecorderDelegate {
    private var isRecording = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechRecognizer = SpeechRecognizer()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "EchoRoute"
        label.backgroundColor = .systemRed
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let titleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // Maintain the aspect ratio
        imageView.clipsToBounds = true
        return imageView
    }()

    private let recordButton: UIButton = {
        let button = UIButton()
        let normalColor = UIColor.red
        let highlightedColor = UIColor.red.withAlphaComponent(0.6) // Darker when highlighted
        button.setTitle("Record", for: .normal)
        button.setBackgroundColor(color: normalColor, forState: .normal)
        button.setBackgroundColor(color: highlightedColor, forState: .highlighted)
        return button
    }()

    private let audioButton: UIButton = {
        let button = UIButton()
        let normalColor = UIColor(hex: "#FFC7C2") ?? .lightGray
        let highlightedColor = normalColor.withAlphaComponent(0.6) // Darker when highlighted
        button.setTitle("Play Audio", for: .normal)
        button.setBackgroundColor(color: normalColor, forState: .normal)
        button.setBackgroundColor(color: highlightedColor, forState: .highlighted)
        return button
    }()
    
    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var audioRecorder: AVAudioRecorder?
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    var shapesLayer: CAShapeLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUserInterface()
        checkCameraPermissions()
        setupCameraPreview()
        setupAudioRecorder()
//        setupShapesLayer()
//        setupModel()
        
        titleImageView.image = UIImage(named: "echoroute-logo-transparent")
        titleImageView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 100)
        view.addSubview(titleImageView)
    }
    
    func setupShapesLayer() {
        shapesLayer = CAShapeLayer()
        shapesLayer.frame = view.bounds
        shapesLayer.strokeColor = UIColor.red.cgColor
        shapesLayer.lineWidth = 2.0
        shapesLayer.fillColor = nil // Transparent fill color

        // Ensure the shapes layer is above the video preview layer
        view.layer.insertSublayer(shapesLayer, above: videoPreviewLayer)
    }
    
    func setupUserInterface() {
//        view.addSubview(titleLabel)
        view.addSubview(recordButton)
        view.addSubview(audioButton)
        

//        view.accessibilityElements = [titleLabel, recordButton, audioButton]
        
        recordButton.addTarget(self, action: #selector(recordButtonPressed), for: .touchDown)
        
        audioButton.addTarget(self, action: #selector(audioButtonPressed), for: .touchDown)
    }
    
    @objc func recordButtonPressed() {
        if isRecording {
            speechRecognizer.stopTranscribing()
            // Set the button color to red when not recording
            recordButton.setBackgroundColor(color: .red, forState: .normal)
            recordButton.setTitle("Record", for: .normal) // Update the title
            
            // Re-enable the Play Audio button when recording stops
            audioButton.isEnabled = true
            audioButton.alpha = 1.0 // Set alpha back to normal for enabled state
        } else {
            speechRecognizer.resetTranscript()
            speechRecognizer.startTranscribing()
            // Set the button color to green when recording
            recordButton.setBackgroundColor(color: .green, forState: .normal)
            recordButton.setTitle("Stop", for: .normal) // Update the title
            
            // Disable the Play Audio button when recording starts
            audioButton.isEnabled = false
            audioButton.alpha = 0.5 // Dim the button to indicate it's disabled
        }
        isRecording.toggle() // Toggle the state
    }
    
    @objc func audioButtonPressed() {
        speakText(speechRecognizer.transcript)
    }
    
    func setupModel() {
        guard let modelURL = Bundle.main.url(forResource: "YourModel", withExtension: "mlmodelc"),
              let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL)) else {
            print("Error loading model")
            return
        }

        self.visionModel = visionModel
        self.request = VNCoreMLRequest(model: visionModel, completionHandler: handleDetectionResults)
        self.request?.imageCropAndScaleOption = .scaleFill
    }

    func handleDetectionResults(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        DispatchQueue.main.async {
            self.drawDetectionsOnPreview(results)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let buttonWidth = view.frame.size.width/2
        let videoLayerHeight = view.frame.size.height - 425
        let buttonHeight = view.frame.size.height - videoLayerHeight
        titleImageView.frame = CGRect(x: 25, y: 40, width: view.frame.size.width - 50, height: 100) // Example frame

//        titleLabel.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 100)
//        recordButton.frame = CGRect(x: 30, y: view.frame.size.height - 150 - view.safeAreaInsets.bottom, width: buttonWidth, height: 55)
//        audioButton.frame = CGRect(x: recordButton.frame.maxX + 30, y: view.frame.size.height - 150 - view.safeAreaInsets.bottom, width: buttonWidth, height: 55)
        
        audioButton.frame = CGRect(x: 0,
                                        y: videoLayerHeight, // Position the button at the bottom of the screen
                                        width: buttonWidth,
                                        height: buttonHeight) // Height is constant
        recordButton.frame = CGRect(x: buttonWidth, // Positioned right after the recordButton
                                          y: videoLayerHeight, // Align with recordButton at the bottom
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
        setupShapesLayer()
        captureSession.startRunning()
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = self.request else {
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform Detection: \(error)")
        }
    }
    
    func drawDetectionsOnPreview(_ observations: [VNRecognizedObjectObservation]) {
        guard let videoLayer = videoPreviewLayer else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapesLayer?.sublayers?.forEach { $0.removeFromSuperlayer() }

        for observation in observations {
            let bbox = VNImageRectForNormalizedRect(observation.boundingBox, Int(videoLayer.frame.width), Int(videoLayer.frame.height))
            let outline = CALayer()
            outline.frame = bbox
            outline.borderWidth = 2.0
            outline.borderColor = UIColor.red.cgColor

            shapesLayer?.addSublayer(outline)
        }
        CATransaction.commit()
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
            // Configure the audio session to use the speaker
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            // Set up the audio recorder
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
        } catch {
            print("Could not set up the audio recorder: \(error)")
        }
    }
    
    // Function to play the text transcript
    private func speakText(_ text: String) {
        var mutableText = text
        
        if !mutableText.isEmpty {
            let utterance = AVSpeechUtterance(string: mutableText)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

            // Configure the audio session for playback (without the .defaultToSpeaker option)
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playback, mode: .default) // No .defaultToSpeaker needed here
                try audioSession.setActive(true)
            } catch {
                print("Failed to set up audio session for playback: \(error)")
            }

            speechSynthesizer.speak(utterance)
        }
    }
    
    // This function will return the URL to the documents directory of the app.
    // It's used to store the recorded audio file.
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
