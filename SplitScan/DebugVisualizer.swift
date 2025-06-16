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
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw the original image
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let cgContext = context.cgContext
            cgContext.setStrokeColor(color.cgColor)
            cgContext.setLineWidth(3.0)
            
            // Draw each box
            for (index, (box, label)) in boxes.enumerated() {
                // Convert normalized coordinates to image coordinates using processBoundingBox
                let imageBox = processBoundingBox(box, imageSize: image.size)
                
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
    
    /// Process a bounding box by rotating it 90° CCW and converting to UIKit coordinates
    private func processBoundingBox(_ boundingBox: CGRect, imageSize: CGSize) -> CGRect {
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
    
    /// Create a debug image showing all recognized text boxes
    func createAllBoxesImage(image: UIImage, texts: [RecognizedText]) -> UIImage {
        print("\n=== All Recognized Text Coordinates ===")
        print("Total texts: \(texts.count)")
        
        let boxes = texts.map { text in
            // Note: Vision's boundingBox is in normalized coordinates (0-1)
            // and uses a coordinate system where (0,0) is at the bottom-left
            let box = text.boundingBox.boundingBox
            let rotated = processBoundingBox(box, imageSize: image.size)
            print("\nText: \"\(text.text)\"")
            print("Rotated and scaled coordinates (pixels):")
            print("  x: \(rotated.origin.x), y: \(rotated.origin.y)")
            print("  width: \(rotated.width), height: \(rotated.height)")
            return box
        }
        print("\n===============================\n")
        return drawBoxesWithoutLabels(on: image, boxes: boxes, color: .blue)
    }
    
    /// Create a debug image showing only price boxes
    func createPriceBoxesImage(image: UIImage, texts: [RecognizedText]) -> UIImage {
        let priceBoxes = texts.compactMap { text -> CGRect? in
            guard let price = text.text.extractPrice() else { return nil }
            return text.boundingBox.boundingBox
        }
        return drawBoxesWithoutLabels(on: image, boxes: priceBoxes, color: .green)
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
            
            // Draw vertical line at price column (in rotated coordinates)
            // Since we rotate 90° CCW, the x-coordinate becomes the y-coordinate
            let x = priceColumnX * image.size.width
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: image.size.height))
            cgContext.strokePath()
            
            // Draw price boxes
            let priceBoxes = texts.compactMap { text -> CGRect? in
                guard let price = text.text.extractPrice() else { return nil }
                return text.boundingBox.boundingBox
            }
            
            // Draw boxes in green
            cgContext.setStrokeColor(UIColor.green.cgColor)
            for box in priceBoxes {
                let imageBox = processBoundingBox(box, imageSize: image.size)
                
                // Draw box with fill
                cgContext.setFillColor(UIColor.green.withAlphaComponent(0.1).cgColor)
                cgContext.fill(imageBox)
                cgContext.stroke(imageBox)
            }
        }
    }
    
    /// Create a debug image showing price boxes and their corresponding item boxes
    func createPriceAndItemBoxesImage(
        image: UIImage,
        texts: [RecognizedText],
        items: [ReceiptItem]
    ) -> UIImage {
        
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw the original image
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let cgContext = context.cgContext
            
            // Draw each item and its price
            for (index, item) in items.enumerated() {
                // Draw item box in blue
                cgContext.setStrokeColor(UIColor.blue.cgColor)
                cgContext.setLineWidth(3.0)
                let itemBox = processBoundingBox(item.boundingBox, imageSize: image.size)
                
                // Draw box with semi-transparent fill
                cgContext.setFillColor(UIColor.blue.withAlphaComponent(0.1).cgColor)
                cgContext.fill(itemBox)
                cgContext.stroke(itemBox)
                
                // Find and draw the corresponding price box
                if let priceText = texts.first(where: { text in
                    guard let price = text.text.extractPrice() else { return false }
                    return price == item.price
                }) {
                    // Draw price box in green
                    cgContext.setStrokeColor(UIColor.green.cgColor)
                    let priceBox = processBoundingBox(priceText.boundingBox.boundingBox, imageSize: image.size)
                    
                    // Draw box with semi-transparent fill
                    cgContext.setFillColor(UIColor.green.withAlphaComponent(0.1).cgColor)
                    cgContext.fill(priceBox)
                    cgContext.stroke(priceBox)
                }
            }
        }
    }
    
    /// Draw bounding boxes on an image without labels
    /// - Parameters:
    ///   - image: The original image
    ///   - boxes: Array of boxes
    ///   - color: Color to draw the boxes
    /// - Returns: New image with boxes drawn
    func drawBoxesWithoutLabels(
        on image: UIImage,
        boxes: [CGRect],
        color: UIColor = .red
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw the original image
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let cgContext = context.cgContext
            cgContext.setStrokeColor(color.cgColor)
            cgContext.setLineWidth(3.0)
            
            // Draw each box
            for box in boxes {
                // Convert normalized coordinates to image coordinates using processBoundingBox
                let imageBox = processBoundingBox(box, imageSize: image.size)
                
                // Draw the box with a thicker line
                cgContext.stroke(imageBox)
                
                // Draw a semi-transparent fill to make boxes more visible
                cgContext.setFillColor(color.withAlphaComponent(0.1).cgColor)
                cgContext.fill(imageBox)
            }
        }
    }
} 
