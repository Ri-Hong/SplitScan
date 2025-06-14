import SwiftUI
import AVFoundation
import Vision
import UIKit

struct LiveTextDetectionCamera: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> LiveTextDetectionCameraViewController {
        let controller = LiveTextDetectionCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: LiveTextDetectionCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: LiveTextDetectionCamera
        
        init(_ parent: LiveTextDetectionCamera) {
            self.parent = parent
        }
        
        func didCaptureImage(_ image: UIImage) {
            parent.capturedImage = image
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func didCancel() {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

class LiveTextDetectionCameraViewController: UIViewController {
    weak var delegate: LiveTextDetectionCamera.Coordinator?
    
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var textDetectionOverlay: TextDetectionOverlayView?
    private var captureButton: UIButton?
    private var cancelButton: UIButton?
    private var statusLabel: UILabel?
    private var statusContainer: UIView?
    private var textDetectionRequest: VNRecognizeTextRequest?
    private var photoOutput: AVCapturePhotoOutput?
    private var isProcessingFrame = false
    private var frameCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
        setupTextDetection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
            return
        }
        
        // Add video output for real-time text detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInteractive))
        
        if captureSession?.canAddOutput(videoOutput) == true {
            captureSession?.addOutput(videoOutput)
        }
        
        // Add photo output for capturing images
        let photoOutput = AVCapturePhotoOutput()
        if captureSession?.canAddOutput(photoOutput) == true {
            captureSession?.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Video preview layer
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        videoPreviewLayer?.frame = view.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        
        // Text detection overlay
        textDetectionOverlay = TextDetectionOverlayView()
        textDetectionOverlay?.frame = view.bounds
        textDetectionOverlay?.backgroundColor = .clear
        view.addSubview(textDetectionOverlay!)
        
        // Capture button - Modern circular button with gradient
        captureButton = UIButton(type: .system)
        captureButton?.setTitle("", for: .normal)
        captureButton?.backgroundColor = .clear
        
        // Create gradient layer for capture button
        let captureGradient = CAGradientLayer()
        captureGradient.colors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemBlue.withAlphaComponent(0.8).cgColor
        ]
        captureGradient.startPoint = CGPoint(x: 0, y: 0)
        captureGradient.endPoint = CGPoint(x: 1, y: 1)
        captureGradient.cornerRadius = 35
        captureButton?.layer.insertSublayer(captureGradient, at: 0)
        
        // Add inner white circle for camera icon effect
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 25
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        captureButton?.addSubview(innerCircle)
        
        // Add shadow to capture button
        captureButton?.layer.shadowColor = UIColor.black.cgColor
        captureButton?.layer.shadowOffset = CGSize(width: 0, height: 4)
        captureButton?.layer.shadowOpacity = 0.3
        captureButton?.layer.shadowRadius = 8
        captureButton?.layer.cornerRadius = 35
        
        captureButton?.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        view.addSubview(captureButton!)
        
        // Cancel button - Modern pill-shaped button
        cancelButton = UIButton(type: .system)
        cancelButton?.setTitle("✕", for: .normal)
        cancelButton?.setTitleColor(.white, for: .normal)
        cancelButton?.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        cancelButton?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        cancelButton?.layer.cornerRadius = 25
        cancelButton?.layer.borderWidth = 2
        cancelButton?.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        // Add shadow to cancel button
        cancelButton?.layer.shadowColor = UIColor.black.cgColor
        cancelButton?.layer.shadowOffset = CGSize(width: 0, height: 2)
        cancelButton?.layer.shadowOpacity = 0.25
        cancelButton?.layer.shadowRadius = 4
        
        cancelButton?.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        view.addSubview(cancelButton!)
        
        // Status label
        statusLabel = UILabel()
        statusLabel?.text = "Point camera at receipt"
        statusLabel?.textColor = .white
        statusLabel?.textAlignment = .center
        statusLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statusLabel?.layer.cornerRadius = 8
        statusLabel?.layer.masksToBounds = true
        
        // Add padding to the label
        statusContainer = UIView()
        statusContainer?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statusContainer?.layer.cornerRadius = 8
        statusContainer?.addSubview(statusLabel!)
        view.addSubview(statusContainer!)
        
        statusLabel?.translatesAutoresizingMaskIntoConstraints = false
        statusContainer?.translatesAutoresizingMaskIntoConstraints = false
        
        // Layout constraints
        captureButton?.translatesAutoresizingMaskIntoConstraints = false
        cancelButton?.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Inner circle constraints for capture button
            innerCircle.centerXAnchor.constraint(equalTo: captureButton!.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: captureButton!.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 50),
            innerCircle.heightAnchor.constraint(equalToConstant: 50),
            
            statusLabel!.topAnchor.constraint(equalTo: statusContainer!.topAnchor, constant: 8),
            statusLabel!.bottomAnchor.constraint(equalTo: statusContainer!.bottomAnchor, constant: -8),
            statusLabel!.leadingAnchor.constraint(equalTo: statusContainer!.leadingAnchor, constant: 16),
            statusLabel!.trailingAnchor.constraint(equalTo: statusContainer!.trailingAnchor, constant: -16),
            
            statusContainer!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusContainer!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            statusContainer!.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            
            captureButton!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton!.widthAnchor.constraint(equalToConstant: 70),
            captureButton!.heightAnchor.constraint(equalToConstant: 70),
            
            cancelButton!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton!.widthAnchor.constraint(equalToConstant: 50),
            cancelButton!.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Update gradient frame after layout
        DispatchQueue.main.async {
            captureGradient.frame = self.captureButton!.bounds
        }
    }
    
    private func setupTextDetection() {
        textDetectionRequest = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            DispatchQueue.main.async {
                self.textDetectionOverlay?.updateBoundingBoxes(observations)
                
                // Update status label
                if observations.count > 0 {
                    self.statusLabel?.text = "Detected \(observations.count) text regions"
                    self.statusLabel?.backgroundColor = UIColor.green.withAlphaComponent(0.7)
                    self.statusContainer?.backgroundColor = UIColor.green.withAlphaComponent(0.7)
                } else {
                    self.statusLabel?.text = "Point camera at receipt"
                    self.statusLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                    self.statusContainer?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                }
            }
        }
        
        textDetectionRequest?.recognitionLevel = .accurate
        textDetectionRequest?.usesLanguageCorrection = true
    }
    
    private func startCamera() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCamera() {
        captureSession?.stopRunning()
    }
    
    @objc private func captureButtonTapped() {
        // Add visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton?.transform = CGAffineTransform.identity
            }
        }
        
        guard let photoOutput = self.photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func cancelButtonTapped() {
        // Add visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.cancelButton?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.cancelButton?.transform = CGAffineTransform.identity
            }
        }
        
        delegate?.didCancel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = view.bounds
        textDetectionOverlay?.frame = view.bounds
    }
}

extension LiveTextDetectionCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        frameCounter += 1
        guard frameCounter % 2 == 0 else { return } // Only process every 2nd frame
        
        isProcessingFrame = true
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try requestHandler.perform([textDetectionRequest!])
        } catch {
            print("Error performing text detection: \(error)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.isProcessingFrame = false
        }
    }
}

extension LiveTextDetectionCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        delegate?.didCaptureImage(image)
    }
}

class TextDetectionOverlayView: UIView {
    private var boundingBoxes: [VNRecognizedTextObservation] = []
    
    /// Process bounding box coordinates using the same transformation as DebugVisualizer
    private func processBoundingBox(_ boundingBox: CGRect, viewSize: CGSize) -> CGRect {
        // Rotate 90° CCW in normalized coordinates
        let rotated = CGRect(
            x: boundingBox.origin.y,
            y: 1 - boundingBox.origin.x - boundingBox.size.width,
            width: boundingBox.size.height,
            height: boundingBox.size.width
        )
        // Convert to UIKit coordinates
        let viewWidth = viewSize.width
        let viewHeight = viewSize.height
        var rect = rotated
        rect.origin.x *= viewWidth
        rect.origin.y = (1 - rect.origin.y - rect.height) * viewHeight // Flip Y and scale
        rect.size.width *= viewWidth
        rect.size.height *= viewHeight
        return rect
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(2.0)
        
        for observation in boundingBoxes {
            let boundingBox = observation.boundingBox
            
            // Convert normalized coordinates to view coordinates using the same transformation
            let viewRect = processBoundingBox(boundingBox, viewSize: bounds.size)
            
            // Draw only outline rectangle (no fill)
            context.stroke(viewRect)
        }
    }
    
    func updateBoundingBoxes(_ observations: [VNRecognizedTextObservation]) {
        boundingBoxes = observations
        setNeedsDisplay()
    }
} 
