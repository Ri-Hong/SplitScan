import SwiftUI
import Combine

class ReceiptViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var recognizedTexts: [SplitScan.RecognizedText] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var shouldNavigateToResult = false
    
    func processImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        shouldNavigateToResult = false
        
        OCRService.shared.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let texts):
                    self?.recognizedTexts = texts
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
        errorMessage = nil
    }
} 
