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
    @Published var priceAndItemBoxesImage: UIImage?
    
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
        priceAndItemBoxesImage = nil
        
        OCRService.shared.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let texts):
                    self.recognizedTexts = texts
                    
                    // Create debug visualization images and process items
                    if let image = self.selectedImage {
                        // Process all visualizations and items first
                        self.allBoxesImage = DebugVisualizer.shared.createAllBoxesImage(image: image, texts: texts)
                        self.priceBoxesImage = DebugVisualizer.shared.createPriceBoxesImage(image: image, texts: texts)
                        
                        if let priceColumnX = ReceiptProcessor.shared.findPriceColumn(texts) {
                            self.priceColumnImage = DebugVisualizer.shared.createPriceColumnImage(
                                image: image,
                                texts: texts,
                                priceColumnX: priceColumnX
                            )
                            self.receiptItems = ReceiptProcessor.shared.processRecognizedText(texts)
                            
                            // Create the price and item boxes image after processing items
                            self.priceAndItemBoxesImage = DebugVisualizer.shared.createPriceAndItemBoxesImage(
                                image: image,
                                texts: texts,
                                items: self.receiptItems
                            )
                        }
                        
                        // Only navigate after all processing is complete
                        if !texts.isEmpty {
                            self.shouldNavigateToResult = true
                        }
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                
                self.isProcessing = false
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
        priceAndItemBoxesImage = nil
    }
} 
