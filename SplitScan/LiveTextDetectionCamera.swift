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
    private var lastAutoCaptureTime: Date = Date.distantPast
    private var autoCaptureDelay: TimeInterval = 2.0 // 2 second delay between auto captures
    private var isAutoCaptureEnabled: Bool = true
    
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
        
        // Capture button
        captureButton = UIButton(type: .system)
        captureButton?.setTitle("", for: .normal)
        captureButton?.backgroundColor = .clear
        
        // Create white circle for capture button
        let captureCircle = UIView()
        captureCircle.backgroundColor = .white
        captureCircle.layer.cornerRadius = 30
        captureCircle.isUserInteractionEnabled = false  // Make circle non-interactive
        captureCircle.translatesAutoresizingMaskIntoConstraints = false
        captureButton?.addSubview(captureCircle)
        
        // Add subtle border to capture button
        captureButton?.layer.borderWidth = 4
        captureButton?.layer.borderColor = UIColor.white.cgColor
        captureButton?.layer.cornerRadius = 34
        
        // Add shadow to capture button
        captureButton?.layer.shadowColor = UIColor.black.cgColor
        captureButton?.layer.shadowOffset = CGSize(width: 0, height: 4)
        captureButton?.layer.shadowOpacity = 0.3
        captureButton?.layer.shadowRadius = 8
        
        captureButton?.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        view.addSubview(captureButton!)
        
        // Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton?.setTitle("✕", for: .normal)
        cancelButton?.setTitleColor(.white, for: .normal)
        cancelButton?.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        cancelButton?.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        cancelButton?.layer.cornerRadius = 25
        
        // Add border to cancel button
        cancelButton?.layer.borderWidth = 2
        cancelButton?.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        
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
            // White circle constraints for capture button
            captureCircle.centerXAnchor.constraint(equalTo: captureButton!.centerXAnchor),
            captureCircle.centerYAnchor.constraint(equalTo: captureButton!.centerYAnchor),
            captureCircle.widthAnchor.constraint(equalToConstant: 60),
            captureCircle.heightAnchor.constraint(equalToConstant: 60),
            
            statusLabel!.topAnchor.constraint(equalTo: statusContainer!.topAnchor, constant: 8),
            statusLabel!.bottomAnchor.constraint(equalTo: statusContainer!.bottomAnchor, constant: -8),
            statusLabel!.leadingAnchor.constraint(equalTo: statusContainer!.leadingAnchor, constant: 16),
            statusLabel!.trailingAnchor.constraint(equalTo: statusContainer!.trailingAnchor, constant: -16),
            
            statusContainer!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusContainer!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            statusContainer!.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            
            captureButton!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton!.widthAnchor.constraint(equalToConstant: 68),
            captureButton!.heightAnchor.constraint(equalToConstant: 68),
            
            cancelButton!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton!.widthAnchor.constraint(equalToConstant: 50),
            cancelButton!.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupTextDetection() {
        textDetectionRequest = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            DispatchQueue.main.async {
                self.textDetectionOverlay?.updateBoundingBoxes(observations)
                
                // Analyze line spacing and provide positioning feedback
                let positioningInstruction = self.analyzeLineSpacingAndProvideInstruction(observations)
                
                // Auto-capture when positioning is perfect
                if positioningInstruction.contains("Perfect") && self.isAutoCaptureEnabled {
                    let now = Date()
                    if now.timeIntervalSince(self.lastAutoCaptureTime) >= self.autoCaptureDelay {
                        self.lastAutoCaptureTime = now
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.autoCapturePhoto()
                        }
                    }
                }
                
                // Update status label with color-coded feedback
                if observations.count > 0 {
                    let autoCaptureText = self.isAutoCaptureEnabled ? " • Auto-capturing..." : ""
                    let baseText = "Detected \(observations.count) text regions • \(positioningInstruction)"
                    
                    // Color-code based on positioning quality
                    if positioningInstruction.contains("Perfect") {
                        self.statusLabel?.text = baseText + autoCaptureText
                        self.statusLabel?.backgroundColor = UIColor.green.withAlphaComponent(0.7)
                        self.statusContainer?.backgroundColor = UIColor.green.withAlphaComponent(0.7)
                    } else if positioningInstruction.contains("too tight") || positioningInstruction.contains("too spread") {
                        self.statusLabel?.text = baseText
                        self.statusLabel?.backgroundColor = UIColor.orange.withAlphaComponent(0.7)
                        self.statusContainer?.backgroundColor = UIColor.orange.withAlphaComponent(0.7)
                    } else {
                        self.statusLabel?.text = baseText
                        self.statusLabel?.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
                        self.statusContainer?.backgroundColor = UIColor.blue.withAlphaComponent(0.7)
                    }
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
    
    /// Analyze the line spacing of detected text and provide camera positioning instructions
    private func analyzeLineSpacingAndProvideInstruction(_ observations: [VNRecognizedTextObservation]) -> String {
        guard observations.count >= 3 else {
            return "Move closer to see more text"
        }
        
        // Extract vertical positions (x coordinates in normalized space)
        let verticalPositions = observations.map { observation in
            observation.boundingBox.origin.x
        }.sorted()
        
        // Calculate line spacing between consecutive text elements
        var lineSpacings: [CGFloat] = []
        for i in 1..<verticalPositions.count {
            let spacing = verticalPositions[i] - verticalPositions[i-1]
            // Only consider reasonable spacings (not too small, not too large)
            if spacing > 0.005 && spacing < 0.1 {
                lineSpacings.append(spacing)
            }
        }
        
        guard lineSpacings.count >= 2 else {
            return "Adjust camera angle"
        }
        
        // Remove outliers using IQR method
        let sortedSpacings = lineSpacings.sorted()
        let q1Index = sortedSpacings.count / 4
        let q3Index = (sortedSpacings.count * 3) / 4
        let q1 = sortedSpacings[q1Index]
        let q3 = sortedSpacings[q3Index]
        let iqr = q3 - q1
        let lowerBound = q1 - (1.5 * iqr)
        let upperBound = q3 + (1.5 * iqr)
        
        let filteredSpacings = sortedSpacings.filter { spacing in
            spacing >= lowerBound && spacing <= upperBound
        }
        
        guard !filteredSpacings.isEmpty else {
            return "Adjust camera angle"
        }
        
        // Calculate median line spacing from filtered data
        let medianSpacing: CGFloat
        if filteredSpacings.count % 2 == 0 {
            let midIndex = filteredSpacings.count / 2
            medianSpacing = (filteredSpacings[midIndex - 1] + filteredSpacings[midIndex]) / 2
        } else {
            medianSpacing = filteredSpacings[filteredSpacings.count / 2]
        }
        
        // Compare with ideal line spacing (0.02)
        let idealSpacing: CGFloat = 0.02
        let tolerance: CGFloat = 0.005 // 0.5% tolerance
        
        if medianSpacing < idealSpacing - tolerance {
            let percentageOff = ((idealSpacing - medianSpacing) / idealSpacing) * 100
            if percentageOff > 25 {
                return "Move much closer - lines very tight"
            } else {
                return "Move closer - lines too tight"
            }
        } else if medianSpacing > idealSpacing + tolerance {
            let percentageOff = ((medianSpacing - idealSpacing) / idealSpacing) * 100
            if percentageOff > 25 {
                return "Move much farther - lines very spread"
            } else {
                return "Move farther - lines too spread"
            }
        } else {
            return "Perfect distance ✓"
        }
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
        guard let photoOutput = self.photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.didCancel()
    }
    
    @objc private func autoCapturePhoto() {
        guard let photoOutput = self.photoOutput else { return }
        
        // Provide visual feedback that auto-capture is happening
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton?.transform = CGAffineTransform.identity
            }
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /// Toggle auto-capture on/off
    func toggleAutoCapture() {
        isAutoCaptureEnabled.toggle()
    }
    
    /// Set auto-capture enabled/disabled
    func setAutoCaptureEnabled(_ enabled: Bool) {
        isAutoCaptureEnabled = enabled
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
