import SwiftUI
import PhotosUI
import Vision

// Constants
private let TAX_RATE: Decimal = 1.13

struct ContentView: View {
    @StateObject private var viewModel = ReceiptViewModel()
    @State private var isShowingImagePicker = false
    @State private var isShowingLiveCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationStack {
            VStack {
                // Image Preview Section
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .padding()
                } else {
                    Image(systemName: "receipt")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                        .padding()
                }
                
                // Camera/Photo Library Buttons
                HStack(spacing: 20) {
                    Button(action: {
                        isShowingLiveCamera = true
                    }) {
                        Label("Take Photo", systemImage: "camera")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        sourceType = .photoLibrary
                        isShowingImagePicker = true
                    }) {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                // Process Button
                if viewModel.selectedImage != nil {
                    Button(action: {
                        viewModel.processImage()
                    }) {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Process Receipt")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(viewModel.isProcessing)
                    .padding(.horizontal)
                }
                
                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("SplitSnap")
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(image: $viewModel.selectedImage, sourceType: sourceType)
            }
            .fullScreenCover(isPresented: $isShowingLiveCamera) {
                LiveTextDetectionCamera(capturedImage: $viewModel.selectedImage)
            }
            .background(
                NavigationLink(
                    destination: SplittingView(
                        image: viewModel.selectedImage ?? UIImage(),
                        recognizedTexts: viewModel.recognizedTexts,
                        viewModel: viewModel
                    ),
                    isActive: $viewModel.shouldNavigateToResult
                ) { EmptyView() }
            )
        }
    }
}

struct DebugView: View {
    @ObservedObject var viewModel: ReceiptViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {  // Remove spacing between sections
                    if let image = viewModel.allBoxesImage {
                        VStack(spacing: 8) {
                            Text("All Recognized Text")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top)
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .border(Color.gray, width: 1)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    if let image = viewModel.priceBoxesImage {
                        VStack(spacing: 8) {
                            Text("Price Boxes")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top)
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .border(Color.gray, width: 1)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    if let image = viewModel.priceColumnImage {
                        VStack(spacing: 8) {
                            Text("Price Column")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top)
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .border(Color.gray, width: 1)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    if let image = viewModel.priceAndItemBoxesImage {
                        VStack(spacing: 8) {
                            Text("Price and Item Boxes")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top)
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .border(Color.gray, width: 1)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                }
            }
            .navigationTitle("Debug Visualization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .edgesIgnoringSafeArea(.bottom)  // Allow content to extend to bottom edge
        }
        .navigationViewStyle(.stack)  // Use stack style to ensure full screen
    }
}

struct ReceiptResultView: View {
    let image: UIImage
    let recognizedTexts: [SplitScan.RecognizedText]
    @ObservedObject var viewModel: ReceiptViewModel
    @State private var showDebugView = false
    
    var body: some View {
        VStack {
            // Debug button
            if showDebugView {
                ScrollView {
                    VStack(spacing: 20) {
                        if let image = viewModel.allBoxesImage {
                            VStack {
                                Text("All Recognized Text")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Image(uiImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .border(Color.gray, width: 1)
                            }
                            .padding(.horizontal)
                        }
                        
                        if let image = viewModel.priceBoxesImage {
                            VStack {
                                Text("Price Boxes")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Image(uiImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .border(Color.gray, width: 1)
                            }
                            .padding(.horizontal)
                        }
                        
                        if let image = viewModel.priceColumnImage {
                            VStack {
                                Text("Price Column")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Image(uiImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .border(Color.gray, width: 1)
                            }
                            .padding(.horizontal)
                        }
                        
                        if let image = viewModel.priceAndItemBoxesImage {
                            VStack {
                                Text("Price and Item Boxes")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Image(uiImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .border(Color.gray, width: 1)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color.gray.opacity(0.1))
            }
            
            // Original receipt items list
            List {
                ForEach(viewModel.receiptItems, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.body) 
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                if item.isTaxed {
                                    Image(systemName: "percent")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Text(String(format: "$%.2f", NSDecimalNumber(decimal: item.isTaxed ? item.price * TAX_RATE : item.price).doubleValue))
                                    .font(.body)
                                    .bold()
                            }
                        }
                        
                        // Secondary line with additional details
                        if item.weight != nil || item.pricePerKg != nil || item.quantity > 1 || item.pricePerCount != nil {
                            HStack {
                                if let weight = item.weight {
                                    Text(String(format: "%.3f kg", NSDecimalNumber(decimal: weight).doubleValue))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let pricePerKg = item.pricePerKg {
                                    Text(String(format: "@ $%.2f/kg", NSDecimalNumber(decimal: pricePerKg).doubleValue))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if item.quantity > 1 {
                                    Text("\(item.quantity) @")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let pricePerCount = item.pricePerCount {
                                    Text(String(format: "$%.2f each", NSDecimalNumber(decimal: pricePerCount).doubleValue))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if !viewModel.receiptItems.isEmpty {
                    Divider()
                    
                    // Calculate totals
                    let total = viewModel.receiptItems.reduce(Decimal(0)) { $0 + ($1.isTaxed ? $1.price * TAX_RATE : $1.price) }
                    let taxedItems = viewModel.receiptItems.filter { $0.isTaxed }
                    let taxedTotal = taxedItems.reduce(Decimal(0)) { $0 + ($1.price * TAX_RATE) }
                    let untaxedTotal = viewModel.receiptItems.filter { !$0.isTaxed }.reduce(Decimal(0)) { $0 + $1.price }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Total:")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "$%.2f", NSDecimalNumber(decimal: total).doubleValue))
                                .font(.headline)
                                .bold()
                        }
                        
                        if !taxedItems.isEmpty {
                            HStack {
                                Text("Taxed Items (\(taxedItems.count)):")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "$%.2f", NSDecimalNumber(decimal: taxedTotal).doubleValue))
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if !viewModel.receiptItems.filter({ !$0.isTaxed }).isEmpty {
                            HStack {
                                Text("Untaxed Items (\(viewModel.receiptItems.filter({ !$0.isTaxed }).count)):")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "$%.2f", NSDecimalNumber(decimal: untaxedTotal).doubleValue))
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                }
            }
            .safeAreaPadding(.vertical)
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDebugView.toggle()
                    }) {
                        Image(systemName: showDebugView ? "eye.slash" : "eye")
                            .foregroundColor(.accentColor)
                            .font(.headline)
                    }
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    ContentView()
} 
