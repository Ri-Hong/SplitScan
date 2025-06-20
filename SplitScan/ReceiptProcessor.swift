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
        
        // Second pass: Process items based on the price column
        var items: [ReceiptItem] = []
        
        // Sort all texts by vertical position (top to bottom)
        let sortedTexts = texts.sorted { text1, text2 in
            let rect1 = text1.boundingBox.boundingBox
            let rect2 = text2.boundingBox.boundingBox
            return rect1.origin.x < rect2.origin.x // x is vertical
        }
        
        // print x, y, and text
        print("\n=== Sorted Text Coordinates ===")
        for text in sortedTexts {
            let box = text.boundingBox.boundingBox
            print("Text: \"\(text.text)\"")
            print("  x: \(box.origin.x), y: \(box.origin.y)")
            print("  width: \(box.width), height: \(box.height)")
        }
        print("===============================\n")
        
        // Filter texts to only those near the price column
        let horizontalTolerance: CGFloat = 0.05 // How close text needs to be to price column
        let textsNearPriceColumn = sortedTexts.filter { text in
            let horizontalPosition = text.boundingBox.boundingBox.origin.y // y is horizontal
            return abs(horizontalPosition - (priceColumnX ?? 0)) < horizontalTolerance
        }
        
        // Process each text near the price column
        for text in textsNearPriceColumn {
            let textString = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If this is a price, look for the item name
            if let price = textString.extractPrice() {
                print("Found price $\(price) at x: \(text.boundingBox.boundingBox.origin.x), y: \(text.boundingBox.boundingBox.origin.y)")
                
                // Find the closest text that's not a price and not a header/footer
                let verticalPosition = text.boundingBox.boundingBox.origin.x // x is vertical
                let rowTolerance: CGFloat = 0.01 // Stricter vertical alignment
                
                // First, look for text to the left of the price on the same line
                let sameLineTexts = sortedTexts.filter { otherText in
                    let otherString = otherText.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let otherVertical = otherText.boundingBox.boundingBox.origin.x
                    let otherHorizontal = otherText.boundingBox.boundingBox.origin.y
                    let priceHorizontal = text.boundingBox.boundingBox.origin.y
                    
                    return !isReceiptHeaderOrFooter(otherString) && // Not a header/footer
                           abs(otherVertical - verticalPosition) < rowTolerance && // Same row
                           otherHorizontal < priceHorizontal // To the left of price
                }
                
                print("Texts on same line as price: ")
                for sameLineText in sameLineTexts {
                    let box = sameLineText.boundingBox.boundingBox
                    print("  - \"\(sameLineText.text)\"")
                    print("    Position: x=\(box.origin.x), y=\(box.origin.y)")
                }
                
                // Check if this is a weight-based or count-based price
                let isWeightBasedPrice = sameLineTexts.contains { text in
                    let text = text.text.lowercased()
                    return text.contains("kg") && text.contains("@") && text.contains("/kg")
                }
                
                let isCountBasedPrice = sameLineTexts.contains { text in
                    let text = text.text.lowercased()
                    return text.contains("@") && !text.contains("kg") && !text.contains("/kg")
                }
                
                if isWeightBasedPrice || isCountBasedPrice {
                    print("Detected \(isWeightBasedPrice ? "weight" : "count")-based price")
                    
                    // Search line by line above until we find a suitable item name
                    let lineSpacing: CGFloat = 0.02 // Approximate spacing between lines
                    let maxLinesToSearch: Int = 5 // Prevent infinite search
                    var allPotentialItems: [(item: RecognizedText, lineOffset: Int)] = []
                    
                    // First, collect all potential items from all lines
                    for lineOffset in 1...maxLinesToSearch {
                        let targetVerticalPosition = verticalPosition - (CGFloat(lineOffset) * lineSpacing)
                        let lineTolerance: CGFloat = 0.01 // Tolerance for finding text on this specific line
                        
                        let textsOnLine = sortedTexts.filter { otherText in
                            let otherString = otherText.text.trimmingCharacters(in: .whitespacesAndNewlines)
                            let otherVertical = otherText.boundingBox.boundingBox.origin.x
                            
                            return otherString.extractPrice() == nil && // Not a price
                                   !isReceiptHeaderOrFooter(otherString) && // Not a header/footer
                                   abs(otherVertical - targetVerticalPosition) < lineTolerance && // On this specific line
                                   otherText.boundingBox.boundingBox.origin.y < text.boundingBox.boundingBox.origin.y // To the left of price
                        }
                        
                        print("Line \(lineOffset) above price line - found \(textsOnLine.count) potential items:")
                        for potentialItem in textsOnLine {
                            let box = potentialItem.boundingBox.boundingBox
                            print("  - \"\(potentialItem.text)\"")
                            print("    Position: x=\(box.origin.x), y=\(box.origin.y)")
                            allPotentialItems.append((item: potentialItem, lineOffset: lineOffset))
                        }
                    }
                    
                    // Now score all collected items and find the best one
                    var bestItem: RecognizedText? = nil
                    var bestScore: Double = 0.0
                    
                    print("Scoring all \(allPotentialItems.count) potential items:")
                    for (potentialItem, lineOffset) in allPotentialItems {
                        let score = calculateItemScore(potentialItem, priceText: text, lineOffset: lineOffset)
                        print("  Score for \"\(potentialItem.text)\" (line \(lineOffset)): \(score)")
                        
                        if score > bestScore {
                            bestScore = score
                            bestItem = potentialItem
                        }
                    }
                    
                    if let bestItem = bestItem {
                        print("Selected best item: \"\(bestItem.text)\" with score \(bestScore)")
                        
                        // Extract weight/quantity and price per unit if available
                        var weight: Decimal?
                        var pricePerKg: Decimal?
                        var quantity: Int = 1
                        var pricePerCount: Decimal?
                        
                        for sameLineText in sameLineTexts {
                            let text = sameLineText.text.lowercased()
                            
                            if isWeightBasedPrice {
                                // Extract weight
                                if let weightMatch = text.range(of: #"(\d+\.?\d*)\s*kg\s*\w*"#, options: .regularExpression) {
                                    let weightStr = String(text[weightMatch])
                                    weight = Decimal(string: weightStr.replacingOccurrences(of: "kg", with: "").trimmingCharacters(in: .whitespaces))
                                }
                                // Extract price per kg
                                if let priceMatch = text.range(of: #"@\s*\w*\s*\$(\d+\.?\d*)\s*\w*/kg"#, options: .regularExpression) {
                                    let priceStr = String(text[priceMatch])
                                    print("Found price per kg string: \"\(priceStr)\"")
                                    if let numberRange = priceStr.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
                                        let numberStr = String(priceStr[numberRange])
                                        pricePerKg = Decimal(string: numberStr)
                                        print("Extracted price per kg: \(pricePerKg ?? 0)")
                                    }
                                }
                            } else if isCountBasedPrice {
                                // Extract quantity
                                if let countMatch = text.range(of: #"(\d+)\s*@"#, options: .regularExpression) {
                                    let countStr = String(text[countMatch])
                                    if let count = Int(countStr.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespaces)) {
                                        quantity = count
                                        print("Extracted quantity: \(quantity)")
                                    }
                                }
                                // Extract price per count
                                if let priceMatch = text.range(of: #"@\s*\$(\d+\.?\d*)"#, options: .regularExpression) {
                                    let priceStr = String(text[priceMatch])
                                    print("Found price per count string: \"\(priceStr)\"")
                                    if let numberRange = priceStr.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
                                        let numberStr = String(priceStr[numberRange])
                                        pricePerCount = Decimal(string: numberStr)
                                        print("Extracted price per count: \(pricePerCount ?? 0)")
                                    }
                                }
                            }
                        }
                        
                        // Check if item is taxed
                        let isTaxed = isItemTaxed(sameLineTexts: sameLineTexts, itemName: bestItem.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        items.append(ReceiptItem(
                            name: cleanItemName(bestItem.text.trimmingCharacters(in: .whitespacesAndNewlines)),
                            price: price,
                            quantity: quantity,
                            boundingBox: bestItem.boundingBox.boundingBox,
                            weight: weight,
                            pricePerKg: pricePerKg,
                            pricePerCount: pricePerCount,
                            isTaxed: isTaxed
                        ))
                    }
                } else {
                    // Regular item price - use the existing logic but with stricter vertical alignment
                    let potentialItemNames: [RecognizedText] = sameLineTexts
                    
                    print("Regular price item - potential names: ")
                    for potentialItem in potentialItemNames {
                        let box = potentialItem.boundingBox.boundingBox
                        print("  - \"\(potentialItem.text)\"")
                        print("    Position: x=\(box.origin.x), y=\(box.origin.y)")
                    }
                    
                    if let bestItem = findBestMatchingItem(potentialItemNames, priceText: text) {
                        let itemName = bestItem.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("Found regular item: \"\(itemName)\"")
                        
                        // Check if item is taxed
                        let isTaxed = isItemTaxed(sameLineTexts: sameLineTexts, itemName: itemName)
                        
                        items.append(ReceiptItem(
                            name: cleanItemName(itemName),
                            price: price,
                            quantity: 1,
                            boundingBox: bestItem.boundingBox.boundingBox,
                            weight: nil,
                            pricePerKg: nil,
                            pricePerCount: nil,
                            isTaxed: isTaxed
                        ))
                    }
                }
            }
        }
        
        print("\n=== Receipt Processing Complete ===")
        print("Total items found: \(items.count)")
        for (index, item) in items.enumerated() {
            let taxStatus = item.isTaxed ? " (Taxed)" : ""
            print("Item \(index + 1): \"\(item.name)\" - $\(item.price)\(taxStatus)")
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
        
        return isHeaderFooter
    }
    
    /// Check if an item is taxed by looking for tax codes in the same line as the price
    /// - Parameters:
    ///   - sameLineTexts: All texts on the same line as the price
    ///   - itemName: The name of the item (in case tax code is part of the name)
    /// - Returns: True if the item is taxed
    private func isItemTaxed(sameLineTexts: [RecognizedText], itemName: String) -> Bool {
        // Check if tax code is in the item name itself
        if itemName.isTaxed() {
            print("Found HMRJ tax code in item name: \"\(itemName)\" - Item is taxed")
            return true
        }
        
        // Check if there's a separate tax code text on the same line
        for sameLineText in sameLineTexts {
            let textString = sameLineText.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if textString.isTaxed() {
                print("Found separate HMRJ tax code: \"\(textString)\" - Item is taxed")
                return true
            } else if textString.containsTaxCode() && !textString.isTaxed() {
                print("Found MRJ tax code: \"\(textString)\" - Item is NOT taxed")
            }
        }
        
        return false
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
    
    private func findBestMatchingItem(_ potentialItems: [RecognizedText], priceText: RecognizedText) -> RecognizedText? {
        return potentialItems.map { item -> (item: RecognizedText, score: Double) in
            let itemBox = item.boundingBox.boundingBox
            let priceBox = priceText.boundingBox.boundingBox
            
            // 0. Check if this is non-item text (tax codes, etc.) - heavy penalty
            if isNonItemText(item.text) {
                return (item: item, score: 0.1) // Very low score for tax codes and other non-item text
            }
            
            // 1. Horizontal distance score (prefer items to the left of price)
            let horizontalDistance = priceBox.origin.y - itemBox.origin.y
            let horizontalScore = horizontalDistance > 0 ? 1.0 : 0.0
            
            // 2. Vertical alignment score (prefer items on same row)
            let verticalDiff = abs(itemBox.origin.x - priceBox.origin.x)
            let verticalScore = 1.0 - (verticalDiff / 0.01) // Using stricter tolerance
            
            // 3. Text length score (prefer longer text for item names)
            let lengthScore = min(Double(item.text.count) / 20.0, 1.0)
            
            // 4. Letter vs Number ratio score (prefer text with more letters)
            let letterCount = item.text.filter { $0.isLetter }.count
            let numberCount = item.text.filter { $0.isNumber }.count
            let totalChars = item.text.count
            let letterRatio = totalChars > 0 ? Double(letterCount) / Double(totalChars) : 0.0
            let letterScore = letterRatio
            
            // 5. Position score (prefer items in the left side of receipt)
            let positionScore = 1.0 - (itemBox.origin.y / 0.5)
            
            let totalScore = (horizontalScore * 0.35) + 
                            (verticalScore * 0.25) + 
                            (lengthScore * 0.15) + 
                            (letterScore * 0.15) + 
                            (positionScore * 0.10)
            
            return (item: item, score: totalScore)
        }.max(by: { $0.score < $1.score })?.item
    }
    
    /// Check if text is likely a tax code or other non-item text
    private func isNonItemText(_ text: String) -> Bool {
        let lowercasedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Tax codes
        if lowercasedText == "mrj" || lowercasedText == "hmrj" {
            return true
        }
        
        // Other common non-item text
        let nonItemPatterns = [
            "net",
            "gst",
            "pst",
            "hst",
            "tax",
            "total",
            "subtotal",
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
        
        return nonItemPatterns.contains { pattern in
            lowercasedText.contains(pattern)
        }
    }
    
    /// Calculate a score for how well a potential item matches the price
    private func calculateItemScore(_ item: RecognizedText, priceText: RecognizedText, lineOffset: Int) -> Double {
        let itemBox = item.boundingBox.boundingBox
        let priceBox = priceText.boundingBox.boundingBox
        
        // 0. Check if this is non-item text (tax codes, etc.) - heavy penalty
        if isNonItemText(item.text) {
            print("    Heavy penalty for non-item text: \"\(item.text)\"")
            return 0.1 // Very low score for tax codes and other non-item text
        }
        
        // 1. Horizontal distance score (prefer items to the left of price)
        let horizontalDistance = priceBox.origin.y - itemBox.origin.y
        let horizontalScore = horizontalDistance > 0 ? 1.0 : 0.0
        
        // 2. Line proximity score (prefer items closer to price line, but allow for gaps)
        let lineProximityScore = max(0.0, 1.0 - (Double(lineOffset) * 0.1)) // Reduce score by 0.1 per line
        
        // 3. Text length score (prefer longer text for item names)
        let lengthScore = min(Double(item.text.count) / 20.0, 1.0)
        
        // 4. Letter vs Number ratio score (prefer text with more letters)
        let letterCount = item.text.filter { $0.isLetter }.count
        let totalChars = item.text.count
        let letterRatio = totalChars > 0 ? Double(letterCount) / Double(totalChars) : 0.0
        let letterScore = letterRatio
        
        // 5. Position score (prefer items in the left side of receipt)
        let positionScore = 1.0 - (itemBox.origin.y / 0.5)
        
        let totalScore = (horizontalScore * 0.30) + 
                        (lineProximityScore * 0.30) + 
                        (lengthScore * 0.15) + 
                        (letterScore * 0.15) + 
                        (positionScore * 0.10)
        
        return totalScore
    }
    
    /// Clean up item name by removing numbers from the beginning and tax codes from the end
    /// - Parameter name: The original item name
    /// - Returns: Cleaned item name with numbers removed from the beginning and tax codes from the end
    private func cleanItemName(_ name: String) -> String {
        var cleanedName = name
        
        // Step 1: Remove numbers and parentheses from the beginning of the name
        // Pattern matches: digits, parentheses, and any combination at the start
        let beginningPattern = #"^[\d\s\(\)]+"#
        
        guard let beginningRegex = try? NSRegularExpression(pattern: beginningPattern) else {
            print("Failed to create regex for beginning name cleaning")
            return name
        }
        
        let beginningRange = NSRange(cleanedName.startIndex..., in: cleanedName)
        cleanedName = beginningRegex.stringByReplacingMatches(
            in: cleanedName,
            range: beginningRange,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 2: Remove tax codes (HMRJ or MRJ) from the end of the name
        // Pattern matches: HMRJ or MRJ at the end, possibly preceded by whitespace
        let endingPattern = #"\s*(HMRJ|MRJ)\s*$"#
        
        guard let endingRegex = try? NSRegularExpression(pattern: endingPattern) else {
            print("Failed to create regex for ending name cleaning")
            return cleanedName
        }
        
        let endingRange = NSRange(cleanedName.startIndex..., in: cleanedName)
        cleanedName = endingRegex.stringByReplacingMatches(
            in: cleanedName,
            range: endingRange,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedName.isEmpty {
            // If cleaning resulted in empty string, return original
            return name
        }
        
        print("Cleaned item name: \"\(name)\" -> \"\(cleanedName)\"")
        return cleanedName
    }
} 
