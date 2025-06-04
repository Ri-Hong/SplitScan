import Vision
import UIKit
import CoreGraphics

extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

enum OCRError: Error {
    case invalidImage
    case noResults
    case processingError
}

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    func recognizeText(from image: UIImage, completion: @escaping (Result<[SplitScan.RecognizedText], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noResults))
                return
            }
            
            let recognizedTexts = observations.compactMap { observation -> SplitScan.RecognizedText? in
                guard let topCandidate = observation.topCandidates(1).first else { return nil }
                
                return SplitScan.RecognizedText(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: observation
                )
            }
            
            completion(.success(recognizedTexts))
        }
        
        // Configure the request
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }

    /// Rotates a CGRect in normalized coordinates 90 degrees clockwise within a unit square, then converts to UIKit coordinates (origin top-left)
    func processBoundingBox(_ boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        // Rotate 90° CCW in normalized coordinates
        let rotated = CGRect(
            x: boundingBox.origin.y,
            y: 1 - boundingBox.origin.x - boundingBox.size.width,
            width: boundingBox.size.height,
            height: boundingBox.size.width
        )
        // Convert to UIKit coordinates
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height
        var rect = rotated
        rect.origin.x *= imageWidth
        rect.origin.y = (1 - rect.origin.y - rect.height) * imageHeight // Flip Y and scale
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        return rect
    }
} 
