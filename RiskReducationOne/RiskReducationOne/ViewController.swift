//
//  ViewController.swift
//  RiskReductionOne
//
//  Created by Aman Arham on 3/12/24.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.isHidden = true  // Hide the imageView since we are using the camera
        return imageView
    }()
    
    private let button: UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.setTitle("Toggle Camera", for: .normal)
        button.setTitleColor(.black, for: .normal)
        return button
    }()
    
    private let audioButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.setTitle("Play Sound", for: .normal)
        button.setTitleColor(.black, for: .normal)
        return button
    }()
    
    let colors: [UIColor] = [
        .systemPink,
        .systemBlue,
        .systemCyan,
        .systemMint,
        .systemIndigo,
        .systemOrange
    ]
    
    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var audioPlayer: AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemCyan
        view.addSubview(imageView)
        imageView.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        imageView.center = view.center
        
        // Load the audioPlayer once when the view loads
        loadAudioPlayer()
        
//        view.addSubview(button)
        view.addSubview(audioButton)
        audioButton.addTarget(self, action: #selector(didTapAudioButton), for: .touchUpInside)
//        button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        checkCameraPermissions()
        setupCameraPreview()
    }
    
    @objc func didTapButton(){
        imageView.isHidden = !imageView.isHidden
        // Toggle camera visibility or handle audio functionality here
        
        view.backgroundColor = colors.randomElement()
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
        
        button.frame = CGRect(x: 30, y: view.frame.size.height-150-view.safeAreaInsets.bottom, width: view.frame.size.width-60, height: 55)
        audioButton.frame = CGRect(x: 30, y: view.frame.size.height-220-view.safeAreaInsets.bottom, width: view.frame.size.width-60, height: 55)
        videoPreviewLayer?.frame = view.layer.bounds
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
    
//    func playSound() {
//            guard let soundURL = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
//                print("Unable to find sound file.")
//                return
//            }
//            
//            do {
//                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
//                audioPlayer?.play()
//            } catch {
//                print("Could not load file: \(error).")
//            }
//    }
    
    func loadAudioPlayer() {
        guard let soundURL = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
            print("Unable to find sound file.")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
        } catch {
            print("Could not load file: \(error).")
        }
    }
}
