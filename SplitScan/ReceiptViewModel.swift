import SwiftUI
import Combine

class ReceiptViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var recognizedTexts: [SplitScan.RecognizedText] = []
    @Published var receiptItems: [ReceiptItem] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var shouldNavigateToResult = false
    
    // Debug visualization images
    @Published var allBoxesImage: UIImage?
    @Published var priceBoxesImage: UIImage?
    @Published var priceColumnImage: UIImage?
    
    func processImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        shouldNavigateToResult = false
        receiptItems = []
        
        // Clear debug images
        allBoxesImage = nil
        priceBoxesImage = nil
        priceColumnImage = nil
        
        OCRService.shared.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let texts):
                    self?.recognizedTexts = texts
                    
                    // Create debug visualization images
                    if let image = self?.selectedImage {
                        self?.allBoxesImage = DebugVisualizer.shared.createAllBoxesImage(image: image, texts: texts)
                        self?.priceBoxesImage = DebugVisualizer.shared.createPriceBoxesImage(image: image, texts: texts)
                        
                        // Process the recognized text into receipt items
                        if let priceColumnX = ReceiptProcessor.shared.findPriceColumn(texts) {
                            self?.priceColumnImage = DebugVisualizer.shared.createPriceColumnImage(
                                image: image,
                                texts: texts,
                                priceColumnX: priceColumnX
                            )
                            self?.receiptItems = ReceiptProcessor.shared.processRecognizedText(texts)
                        }
                    }
                    
                    if !texts.isEmpty {
                        self?.shouldNavigateToResult = true
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func clearResults() {
        recognizedTexts = []
        receiptItems = []
        errorMessage = nil
        allBoxesImage = nil
        priceBoxesImage = nil
        priceColumnImage = nil
    }
} 
