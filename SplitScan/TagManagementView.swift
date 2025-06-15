import SwiftUI

struct TagManagementView: View {
    @ObservedObject var splitViewModel: SplitViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                // Tags List
                List {
                    ForEach(splitViewModel.tags) { tag in
                        HStack {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 20, height: 20)
                            
                            Text(tag.name)
                                .font(.body)
                            
                            Spacer()
                            
                            Button(action: {
                                splitViewModel.removeTag(tag)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Add Tag Button
                if splitViewModel.canAddMoreTags {
                    Button(action: {
                        splitViewModel.showingAddTagSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Tag")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else {
                    Text("Maximum 5 tags allowed")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $splitViewModel.showingAddTagSheet) {
                AddTagView(splitViewModel: splitViewModel)
            }
        }
    }
} 
