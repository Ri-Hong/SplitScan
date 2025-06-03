import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = selectedImage {
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
                
                Spacer()
            }
            .navigationTitle("SplitSnap")
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: sourceType)
            }
            .sheet(isPresented: $isShowingCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
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
