import Vision

struct RecognizedText: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: VNRectangleObservation
    
    static func == (lhs: RecognizedText, rhs: RecognizedText) -> Bool {
        lhs.id == rhs.id && 
        lhs.text == rhs.text && 
        lhs.confidence == rhs.confidence
    }
} 
