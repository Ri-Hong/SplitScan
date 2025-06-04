import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = ReceiptViewModel()
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isNavigatingToResult = false
    
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
                        sourceType = .camera
                        isShowingCamera = true
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
            .sheet(isPresented: $isShowingCamera) {
                ImagePicker(image: $viewModel.selectedImage, sourceType: .camera)
            }
            .background(
                NavigationLink(
                    destination: ReceiptResultView(
                        image: viewModel.selectedImage ?? UIImage(),
                        recognizedTexts: viewModel.recognizedTexts
                    ),
                    isActive: $viewModel.shouldNavigateToResult
                ) { EmptyView() }
            )
        }
    }
}

struct ReceiptResultView: View {
    let image: UIImage
    let recognizedTexts: [RecognizedText]
    @State private var showDebug = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Scanned Items")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { showDebug.toggle() }) {
                    Text(showDebug ? "Hide Debug" : "Show Debug")
                        .font(.caption)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding([.top, .horizontal])
            
            if showDebug {
                GeometryReader { geometry in
                    let containerSize = geometry.size
                    let normalizedImage = image.normalizedImage()
                    let imageSize = normalizedImage.size
                    let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
                    let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                    let xOffset = (containerSize.width - displayedSize.width) / 2
                    let yOffset = (containerSize.height - displayedSize.height) / 2
                    ZStack {
                        Image(uiImage: normalizedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: displayedSize.width, height: displayedSize.height)
                            .position(x: containerSize.width / 2, y: containerSize.height / 2)
                        ForEach(recognizedTexts) { text in
                            let rect = text.boundingBoxInPixels(for: imageSize)
                            Rectangle()
                                .stroke(Color.blue, lineWidth: 2)
                                .frame(width: rect.width * scale, height: rect.height * scale)
                                .position(
                                    x: (rect.midX * scale) + xOffset,
                                    y: (rect.midY * scale) + yOffset
                                )
                        }
                    }
                }
                .frame(height: 300)
            }
            
            List {
                ForEach(recognizedTexts) { text in
                    VStack(alignment: .leading) {
                        Text(text.text)
                            .font(.body)
                        Text("Confidence: \(Int(text.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
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
