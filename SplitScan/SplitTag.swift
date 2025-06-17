import SwiftUI

struct SplitTag: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var color: Color
    
    init(name: String, color: Color) {
        self.name = name
        self.color = color
    }
    
    static func == (lhs: SplitTag, rhs: SplitTag) -> Bool {
        return lhs.id == rhs.id
    }
}

// Predefined colors for tags
extension SplitTag {
    static let defaultColors: [Color] = [
        .blue, .red, .green, .orange, .purple, .pink, .yellow, .mint, .teal, .indigo
    ]
    
    static func createDefaultTags() -> [SplitTag] {
        return [
            SplitTag(name: "Person 1", color: .green),
            SplitTag(name: "Person 2", color: .red)
        ]
    }
} 
