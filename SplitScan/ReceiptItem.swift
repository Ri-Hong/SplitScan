import Foundation

struct ReceiptItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Decimal
    let quantity: Int
    let boundingBox: CGRect  // Store the position for UI purposes
    
    init(name: String, price: Decimal, quantity: Int = 1, boundingBox: CGRect) {
        self.name = name
        self.price = price
        self.quantity = quantity
        self.boundingBox = boundingBox
    }
}

// Extension to help with price parsing
extension String {
    func extractPrice() -> Decimal? {
        // Match only $1.99 or 1.99 format (must have 2 decimal places)
        let pattern = #"[$]?\d+\.\d{2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else {
            return nil
        }
        
        let priceString = (self as NSString).substring(with: match.range)
            .replacingOccurrences(of: "$", with: "")
        
        return Decimal(string: priceString)
    }
} 
