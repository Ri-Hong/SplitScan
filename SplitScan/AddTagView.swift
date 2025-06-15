import SwiftUI

struct AddTagView: View {
    @ObservedObject var splitViewModel: SplitViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Tag Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag Name")
                        .font(.headline)
                    
                    TextField("Enter tag name", text: $splitViewModel.newTagName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                // Color Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(SplitTag.defaultColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(splitViewModel.selectedColor == color ? Color.black : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    splitViewModel.selectedColor = color
                                }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        splitViewModel.addTag()
                    }
                    .disabled(splitViewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
} 
