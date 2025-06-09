import Foundation

struct ReceiptItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Decimal
    let quantity: Int
    let boundingBox: CGRect  // Store the position for UI purposes
    let weight: Decimal?
    let pricePerKg: Decimal?
    let pricePerCount: Decimal?  // New field for count-based items
    let isTaxed: Bool  // New field to track if item is taxed
    
    init(name: String, price: Decimal, quantity: Int = 1, boundingBox: CGRect, 
         weight: Decimal? = nil, pricePerKg: Decimal? = nil, pricePerCount: Decimal? = nil, isTaxed: Bool = false) {
        self.name = name
        self.price = price
        self.quantity = quantity
        self.boundingBox = boundingBox
        self.weight = weight
        self.pricePerKg = pricePerKg
        self.pricePerCount = pricePerCount
        self.isTaxed = isTaxed
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
    
    /// Check if the string contains a tax code (HMRJ or MRJ)
    func containsTaxCode() -> Bool {
        let taxPatterns = ["HMRJ", "MRJ"]
        let upperText = self.uppercased()
        return taxPatterns.contains { pattern in
            upperText.contains(pattern)
        }
    }
    
    /// Extract tax code from the string if present
    func extractTaxCode() -> String? {
        let taxPatterns = ["HMRJ", "MRJ"]
        let upperText = self.uppercased()
        
        for pattern in taxPatterns {
            if upperText.contains(pattern) {
                return pattern
            }
        }
        return nil
    }
    
    /// Check if the string contains a tax code that indicates the item is taxed
    /// HMRJ = taxed, MRJ = not taxed
    func isTaxed() -> Bool {
        let upperText = self.uppercased()
        return upperText.contains("HMRJ")
    }
} 
