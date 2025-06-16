import SwiftUI

// Constants
private let TAX_RATE: Decimal = 1.13

struct SplittingView: View {
    let image: UIImage
    let recognizedTexts: [SplitScan.RecognizedText]
    @ObservedObject var viewModel: ReceiptViewModel
    @StateObject private var splitViewModel = SplitViewModel()
    @State private var showDebugView = false
    @State private var selectedItem: ReceiptItem?
    @State private var showItemAssignment = false
    @State private var showSummary = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tags Section
            VStack(spacing: 12) {
                HStack {
                    Text("Split Between")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                // Tags Display
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(splitViewModel.tags) { tag in
                            TagView(
                                tag: tag, 
                                total: splitViewModel.getTotalForTag(tag, items: viewModel.receiptItems),
                                defaultSplit: splitViewModel.getDefaultSplitPerTag(items: viewModel.receiptItems)
                            )
                            .onTapGesture {
                                splitViewModel.startEditingTag(tag)
                            }
                        }
                        
                        // Add Tag Button (plus icon)
                        if splitViewModel.canAddMoreTags {
                            AddTagButtonView {
                                splitViewModel.showingAddTagSheet = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 0)
            .padding(.bottom, 12)
            .background(Color.gray.opacity(0.1))
            
            // Debug View (if enabled)
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
            
            // Items List
            List {
                ForEach(viewModel.receiptItems, id: \.id) { item in
                    ItemRowView(
                        item: item,
                        splitViewModel: splitViewModel,
                        onTap: {
                            print("Setting selectedItem to: \(item.name)")
                            selectedItem = item
                            print("Setting showItemAssignment to true")
                            showItemAssignment = true
                        }
                    )
                }
                
                if !viewModel.receiptItems.isEmpty {
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
            
            // Done Button
            VStack(spacing: 0) {
                Divider()
                
                Button(action: {
                    showSummary = true
                }) {
                    HStack {
                        Spacer()
                        Text("Done")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .navigationTitle("Split Receipt")
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
        .sheet(isPresented: $splitViewModel.showingAddTagSheet) {
            AddTagView(splitViewModel: splitViewModel)
        }
        .sheet(item: $splitViewModel.editingTag) { tag in
            EditTagView(splitViewModel: splitViewModel)
        }
        .sheet(isPresented: $showItemAssignment, content: {
            if let item = selectedItem {
                ItemAssignmentView(item: item, splitViewModel: splitViewModel)
            } else {
                // Fallback view if no item is selected
                VStack {
                    Text("No item selected")
                        .font(.headline)
                    Button("Dismiss") {
                        showItemAssignment = false
                    }
                    .padding()
                }
            }
        })
        .sheet(isPresented: $showSummary) {
            SummaryView(items: viewModel.receiptItems, splitViewModel: splitViewModel)
        }
    }
}
private let TAG_HEIGHT: CGFloat = 50
struct TagView: View {
    let tag: SplitTag
    let total: Decimal
    let defaultSplit: Decimal

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 12, height: 12)

                Text(tag.name)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Text(String(format: "$%.2f", NSDecimalNumber(decimal: total).doubleValue))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: TAG_HEIGHT)
        .background(tag.color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tag.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AddTagButtonView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Spacer()
            }
            .frame(height: TAG_HEIGHT)
            .frame(minWidth: 24) // Optional width control
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ItemRowView: View {
    let item: ReceiptItem
    @ObservedObject var splitViewModel: SplitViewModel
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
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
                        .foregroundColor(.primary)
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
            
            // Assigned tags
            let assignedTags = splitViewModel.getAssignedTagsForItem(itemId: item.id)
            if !assignedTags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(assignedTags) { tag in
                        HStack(spacing: 2) {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 8, height: 8)
                            Text(tag.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tag.color.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            } else if !splitViewModel.tags.isEmpty {
                // Show that item will be split by default
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Split between all (\(splitViewModel.tags.count))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            print("Item tapped: \(item.name)")
            onTap()
        }
    }
}

struct ItemAssignmentView: View {
    let item: ReceiptItem
    @ObservedObject var splitViewModel: SplitViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Item Info
                VStack(spacing: 8) {
                    Text(item.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(String(format: "$%.2f", NSDecimalNumber(decimal: item.isTaxed ? item.price * TAX_RATE : item.price).doubleValue))
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    
                    if item.isTaxed {
                        Text("Taxed Item")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Tag Assignment
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assign to:")
                        .font(.headline)
                    
                    if splitViewModel.tags.isEmpty {
                        Text("No tags available. Please add tags first.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(splitViewModel.tags) { tag in
                            Button(action: {
                                splitViewModel.toggleItemAssignment(itemId: item.id, tagId: tag.id)
                            }) {
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 20, height: 20)
                                    
                                    Text(tag.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if splitViewModel.isItemAssignedToTag(itemId: item.id, tagId: tag.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title2)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                            .font(.title2)
                                    }
                                }
                                .padding()
                                .background(splitViewModel.isItemAssignedToTag(itemId: item.id, tagId: tag.id) ? tag.color.opacity(0.1) : Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Default split info
                        let assignedTags = splitViewModel.getAssignedTagsForItem(itemId: item.id)
                        if assignedTags.isEmpty {
                            VStack(spacing: 8) {
                                
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("No tags selected")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                                
                                Text("This item will be automatically split equally between all \(splitViewModel.tags.count) people.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Assign Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EditTagView: View {
    @ObservedObject var splitViewModel: SplitViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Edit Tag Name")
                    .font(.headline)
                
                TextField("Tag name", text: $splitViewModel.editingTagName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        splitViewModel.cancelEditingTag()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        splitViewModel.updateTagName()
                    }
                    .disabled(splitViewModel.editingTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
} 
