import UIKit
import Vision

class DebugVisualizer {
    static let shared = DebugVisualizer()
    
    private init() {}
    
    /// Draw bounding boxes on an image with optional labels
    /// - Parameters:
    ///   - image: The original image
    ///   - boxes: Array of boxes with their labels
    ///   - color: Color to draw the boxes
    /// - Returns: New image with boxes drawn
    func drawBoxes(
        on image: UIImage,
        boxes: [(box: CGRect, label: String)],
        color: UIColor = .red
    ) -> UIImage {
        print("\n=== Drawing Bounding Boxes ===")
        print("Image size: \(image.size)")
        print("Number of boxes to draw: \(boxes.count)")
        
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw the original image
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let cgContext = context.cgContext
            cgContext.setStrokeColor(color.cgColor)
            cgContext.setLineWidth(3.0)
            
            // Draw each box
            for (index, (box, label)) in boxes.enumerated() {
                print("\nBox \(index + 1):")
                print("Normalized box: \(box)")
                
                // Convert normalized coordinates to image coordinates
                let imageBox = CGRect(
                    x: box.origin.x * image.size.width,
                    y: box.origin.y * image.size.height,
                    width: box.width * image.size.width,
                    height: box.height * image.size.height
                )
                print("Image coordinates box: \(imageBox)")
                print("Label: \(label)")
                
                // Draw the box with a thicker line
                cgContext.stroke(imageBox)
                
                // Draw a semi-transparent fill to make boxes more visible
                cgContext.setFillColor(color.withAlphaComponent(0.1).cgColor)
                cgContext.fill(imageBox)
                
                // Draw the label with a more visible background
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: color
                ]
                
                let labelSize = (label as NSString).size(withAttributes: labelAttributes)
                let labelRect = CGRect(
                    x: imageBox.origin.x,
                    y: imageBox.origin.y - labelSize.height - 4,
                    width: labelSize.width,
                    height: labelSize.height
                )
                
                // Draw a more visible background for label
                UIColor.white.setFill()
                cgContext.fill(labelRect.insetBy(dx: -4, dy: -4))
                
                // Draw a border around the label background
                cgContext.setStrokeColor(color.cgColor)
                cgContext.stroke(labelRect.insetBy(dx: -4, dy: -4))
                
                // Draw the label text
                (label as NSString).draw(in: labelRect, withAttributes: labelAttributes)
            }
        }
    }
    
    /// Create a debug image showing all recognized text boxes
    func createAllBoxesImage(image: UIImage, texts: [RecognizedText]) -> UIImage {
        print("\n=== Creating All Boxes Image ===")
        print("Number of texts: \(texts.count)")
        
        let boxes = texts.map { text in
            // Note: Vision's boundingBox is in normalized coordinates (0-1)
            // and uses a coordinate system where (0,0) is at the bottom-left
            let box = text.boundingBox.boundingBox
            print("\nText: \"\(text.text)\"")
            print("Original Vision box: \(box)")
            
            let normalizedBox = CGRect(
                x: box.origin.x,
                y: 1 - box.origin.y - box.height, // Flip Y coordinate
                width: box.width,
                height: box.height
            )
            print("Normalized box: \(normalizedBox)")
            return (box: normalizedBox, label: text.text)
        }
        return drawBoxes(on: image, boxes: boxes, color: .blue)
    }
    
    /// Create a debug image showing only price boxes
    func createPriceBoxesImage(image: UIImage, texts: [RecognizedText]) -> UIImage {
        let priceBoxes = texts.compactMap { text -> (CGRect, String)? in
            guard let price = text.text.extractPrice() else { return nil }
            let box = text.boundingBox.boundingBox
            let normalizedBox = CGRect(
                x: box.origin.x,
                y: 1 - box.origin.y - box.height, // Flip Y coordinate
                width: box.width,
                height: box.height
            )
            return (normalizedBox, String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue))
        }
        return drawBoxes(on: image, boxes: priceBoxes, color: .green)
    }
    
    /// Create a debug image showing the price column
    func createPriceColumnImage(
        image: UIImage,
        texts: [RecognizedText],
        priceColumnX: CGFloat
    ) -> UIImage {
        // Draw a vertical line at the price column
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw the original image
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let cgContext = context.cgContext
            cgContext.setStrokeColor(UIColor.red.cgColor)
            cgContext.setLineWidth(3.0)
            
            // Draw vertical line at price column
            let x = priceColumnX * image.size.width
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: image.size.height))
            cgContext.strokePath()
            
            // Draw price boxes
            let priceBoxes = texts.compactMap { text -> (CGRect, String)? in
                guard let price = text.text.extractPrice() else { return nil }
                let box = text.boundingBox.boundingBox
                let normalizedBox = CGRect(
                    x: box.origin.x,
                    y: 1 - box.origin.y - box.height, // Flip Y coordinate
                    width: box.width,
                    height: box.height
                )
                return (normalizedBox, String(format: "$%.2f", NSDecimalNumber(decimal: price).doubleValue))
            }
            
            // Draw boxes in green
            cgContext.setStrokeColor(UIColor.green.cgColor)
            for (box, label) in priceBoxes {
                let imageBox = CGRect(
                    x: box.origin.x * image.size.width,
                    y: box.origin.y * image.size.height,
                    width: box.width * image.size.width,
                    height: box.height * image.size.height
                )
                
                // Draw box with fill
                cgContext.setFillColor(UIColor.green.withAlphaComponent(0.1).cgColor)
                cgContext.fill(imageBox)
                cgContext.stroke(imageBox)
                
                // Draw label with background
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.green
                ]
                
                let labelSize = (label as NSString).size(withAttributes: labelAttributes)
                let labelRect = CGRect(
                    x: imageBox.origin.x,
                    y: imageBox.origin.y - labelSize.height - 4,
                    width: labelSize.width,
                    height: labelSize.height
                )
                
                UIColor.white.setFill()
                cgContext.fill(labelRect.insetBy(dx: -4, dy: -4))
                cgContext.setStrokeColor(UIColor.green.cgColor)
                cgContext.stroke(labelRect.insetBy(dx: -4, dy: -4))
                (label as NSString).draw(in: labelRect, withAttributes: labelAttributes)
            }
        }
    }
} 
