import Foundation
import Vision

class ReceiptProcessor {
    static let shared = ReceiptProcessor()
    
    private init() {}
    
    /// Process recognized text to extract items and their prices
    /// - Parameter texts: Array of recognized text with their positions
    /// - Returns: Array of receipt items with their prices
    func processRecognizedText(_ texts: [RecognizedText]) -> [ReceiptItem] {
        print("\n=== Starting Receipt Processing ===")
        print("Total lines of text to process: \(texts.count)")
        
        // First pass: Find all prices and their positions
        var pricePositions: [(text: RecognizedText, price: Decimal, xPosition: CGFloat)] = []
        
        for text in texts {
            let textString = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let price = textString.extractPrice() {
                // Store the price and its x position (horizontal position since coordinates are flipped)
                pricePositions.append((
                    text: text,
                    price: price,
                    xPosition: text.boundingBox.boundingBox.origin.y // y is horizontal
                ))
                print("Found price: $\(price) at x-position \(text.boundingBox.boundingBox.origin.y)")
            }
        }
        
        // Find the most common x-position for prices (price column)
        let priceColumnX = findPriceColumn(texts)
        print("\nIdentified price column at x-position: \(priceColumnX?.description ?? "N/A")")
        
        // Second pass: Process items based on the price column
        var items: [ReceiptItem] = []
        
        // Sort all texts by vertical position (y coordinate since it's flipped)
        let sortedTexts = texts.sorted { text1, text2 in
            let rect1 = text1.boundingBox.boundingBox
            let rect2 = text2.boundingBox.boundingBox
            return rect1.origin.x < rect2.origin.x // x is vertical
        }
        
        // Group texts by vertical position (y coordinate since it's flipped)
        let verticalGroups = groupTextsByVerticalPosition(sortedTexts)
        
        // Process each vertical group
        for (verticalPosition, groupTexts) in verticalGroups {
            print("\n--- Processing vertical group at y=\(verticalPosition) ---")
            
            // Find the price in this group (if any)
            let priceInGroup = pricePositions.first { pricePos in
                // Check if price is in this vertical group and close to price column
                let priceY = pricePos.text.boundingBox.boundingBox.origin.x // x is vertical
                let priceX = pricePos.text.boundingBox.boundingBox.origin.y // y is horizontal
                return abs(priceY - verticalPosition) < 0.02 && // Close vertically
                       abs(priceX - (priceColumnX ?? 0)) < 0.05 // Close to price column
            }
            
            if let pricePos = priceInGroup {
                print("Found price in group: $\(pricePos.price)")
                
                // Find the item name in this group
                // Look for text that's not a price and not a header/footer
                let potentialItemNames = groupTexts.filter { text in
                    let textString = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return textString.extractPrice() == nil && // Not a price
                           !isReceiptHeaderOrFooter(textString) // Not a header/footer
                }
                
                if let itemText = potentialItemNames.first {
                    let itemName = itemText.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Found item name: \"\(itemName)\"")
                    
                    items.append(ReceiptItem(
                        name: itemName,
                        price: pricePos.price,
                        boundingBox: itemText.boundingBox.boundingBox
                    ))
                } else {
                    print("No item name found for price $\(pricePos.price)")
                }
            }
        }
        
        print("\n=== Receipt Processing Complete ===")
        print("Total items found: \(items.count)")
        for (index, item) in items.enumerated() {
            print("Item \(index + 1): \"\(item.name)\" - $\(item.price)")
        }
        print("===============================\n")
        
        return items
    }
    
    /// Find the most common x-position for prices (price column)
    func findPriceColumn(_ texts: [RecognizedText]) -> CGFloat? {
        // First find all prices and their positions
        var pricePositions: [(xPosition: CGFloat, count: Int)] = []
        let tolerance: CGFloat = 0.05
        
        for text in texts {
            if let price = text.text.extractPrice() {
                let xPosition = text.boundingBox.boundingBox.origin.y // y is horizontal
                
                // Find the closest existing group or create a new one
                if let existingIndex = pricePositions.firstIndex(where: { abs($0.xPosition - xPosition) < tolerance }) {
                    pricePositions[existingIndex].count += 1
                } else {
                    pricePositions.append((xPosition: xPosition, count: 1))
                }
            }
        }
        
        // Find the most common position
        guard let mostCommonPosition = pricePositions.max(by: { $0.count < $1.count })?.xPosition else {
            return nil
        }
        
        print("Price column analysis:")
        for (position, count) in pricePositions {
            print("Position \(position): \(count) prices")
        }
        
        return mostCommonPosition
    }
    
    /// Group texts by their vertical position
    private func groupTextsByVerticalPosition(_ texts: [RecognizedText]) -> [CGFloat: [RecognizedText]] {
        var groups: [CGFloat: [RecognizedText]] = [:]
        let tolerance: CGFloat = 0.02 // How close texts need to be to be considered in the same group
        
        for text in texts {
            let verticalPosition = text.boundingBox.boundingBox.origin.x // x is vertical
            
            // Find the closest existing group or create a new one
            if let existingPosition = groups.keys.first(where: { abs($0 - verticalPosition) < tolerance }) {
                groups[existingPosition, default: []].append(text)
            } else {
                groups[verticalPosition] = [text]
            }
        }
        
        return groups
    }
    
    /// Check if a line of text is likely a receipt header or footer
    private func isReceiptHeaderOrFooter(_ text: String) -> Bool {
        let headerFooterPatterns = [
            "total",
            "subtotal",
            "tax",
            "change",
            "cash",
            "credit",
            "debit",
            "visa",
            "mastercard",
            "thank you",
            "receipt",
            "date:",
            "time:",
            "store",
            "register"
        ]
        
        let lowercasedText = text.lowercased()
        let isHeaderFooter = headerFooterPatterns.contains { pattern in
            lowercasedText.contains(pattern)
        }
        
        if isHeaderFooter {
            print("Matched header/footer pattern: \"\(text)\"")
        }
        
        return isHeaderFooter
    }
    
    /// Try to extract an item name from a line that might contain a price
    private func extractItemNameFromLine(_ text: String) -> String? {
        // Remove price from the line to get the item name
        let pattern = #"[$]?\d+(\.\d{2})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            print("Failed to create regex for price extraction")
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let modifiedText = regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if modifiedText.isEmpty {
            print("No item name found after removing price")
            return nil
        }
        
        print("Extracted item name: \"\(modifiedText)\"")
        return modifiedText
    }
} 
