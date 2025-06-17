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
    @State private var showSummary = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tags Section
            TagsSectionView(splitViewModel: splitViewModel, viewModel: viewModel)
            
            // Debug View (if enabled)
            if showDebugView {
                DebugSectionView(viewModel: viewModel)
            }
            
            // Items List
            ItemsListView(
                viewModel: viewModel,
                splitViewModel: splitViewModel,
                selectedItem: $selectedItem
            )
            
            // Done Button
            DoneButtonView(showSummary: $showSummary)
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
        .sheet(item: $selectedItem) { item in
            ItemAssignmentView(item: item, splitViewModel: splitViewModel)
        }
        .sheet(isPresented: $showSummary) {
            SummaryView(items: viewModel.filteredReceiptItems, splitViewModel: splitViewModel)
        }
    }
}

// MARK: - Sub-Views
struct TagsSectionView: View {
    @ObservedObject var splitViewModel: SplitViewModel
    @ObservedObject var viewModel: ReceiptViewModel
    
    var body: some View {
        GeometryReader { geometry in
            TagsContent(
                splitViewModel: splitViewModel,
                viewModel: viewModel,
                isLargeDevice: geometry.size.width > 768
            )
        }
        .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 80)
    }
}

struct TagsContent: View {
    @ObservedObject var splitViewModel: SplitViewModel
    @ObservedObject var viewModel: ReceiptViewModel
    let isLargeDevice: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Split Between")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Tags Display
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isLargeDevice ? 16 : 12) {
                    ForEach(splitViewModel.tags) { tag in
                        TagView(
                            tag: tag, 
                            total: splitViewModel.getTotalForTag(tag, items: viewModel.receiptItems),
                            defaultSplit: splitViewModel.getDefaultSplitPerTag(items: viewModel.receiptItems),
                            isLargeDevice: isLargeDevice
                        )
                        .onTapGesture {
                            splitViewModel.startEditingTag(tag)
                        }
                    }
                    
                    // Add Tag Button (plus icon)
                    if splitViewModel.canAddMoreTags {
                        AddTagButtonView(onTap: {
                            splitViewModel.showingAddTagSheet = true
                        }, isLargeDevice: isLargeDevice)
                    }
                }
                .padding(.horizontal, isLargeDevice ? 20 : 0)
            }
        }
        .padding(.horizontal, isLargeDevice ? 24 : 16)
        .padding(.top, 0)
        .padding(.bottom, isLargeDevice ? 16 : 12)
        .background(Color.gray.opacity(0.1))
    }
}

struct DebugSectionView: View {
    @ObservedObject var viewModel: ReceiptViewModel
    
    var body: some View {
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
}

struct ItemsListView: View {
    @ObservedObject var viewModel: ReceiptViewModel
    @ObservedObject var splitViewModel: SplitViewModel
    @Binding var selectedItem: ReceiptItem?
    
    var body: some View {
        List {
            ForEach(viewModel.filteredReceiptItems, id: \.id) { item in
                ItemRowView(
                    item: item,
                    splitViewModel: splitViewModel,
                    onTap: {
                        print("Setting selectedItem to: \(item.name)")
                        selectedItem = item
                    }
                )
            }
            
            if !viewModel.filteredReceiptItems.isEmpty {
                TotalsView(items: viewModel.filteredReceiptItems)
            }
        }
    }
}

struct TotalsView: View {
    let items: [ReceiptItem]
    
    var body: some View {
        let total = items.reduce(Decimal(0)) { $0 + ($1.isTaxed ? $1.price * TAX_RATE : $1.price) }
        let taxedItems = items.filter { $0.isTaxed }
        let taxedTotal = taxedItems.reduce(Decimal(0)) { $0 + ($1.price * TAX_RATE) }
        let untaxedTotal = items.filter { !$0.isTaxed }.reduce(Decimal(0)) { $0 + $1.price }
        
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
            
            if !items.filter({ !$0.isTaxed }).isEmpty {
                HStack {
                    Text("Untaxed Items (\(items.filter({ !$0.isTaxed }).count)):")
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

struct DoneButtonView: View {
    @Binding var showSummary: Bool
    
    var body: some View {
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
}

private let TAG_HEIGHT: CGFloat = 50
struct TagView: View {
    let tag: SplitTag
    let total: Decimal
    let defaultSplit: Decimal
    let isLargeDevice: Bool

    var body: some View {
        VStack(spacing: isLargeDevice ? 6 : 4) {
            HStack(spacing: isLargeDevice ? 8 : 6) {
                Circle()
                    .fill(tag.color)
                    .frame(width: isLargeDevice ? 16 : 12, height: isLargeDevice ? 16 : 12)

                Text(tag.name)
                    .font(isLargeDevice ? .body : .caption)
                    .fontWeight(.medium)
            }

            Text(String(format: "$%.2f", NSDecimalNumber(decimal: total).doubleValue))
                .font(isLargeDevice ? .caption : .caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, isLargeDevice ? 16 : 12)
        .padding(.vertical, isLargeDevice ? 12 : 8)
        .frame(height: isLargeDevice ? 70 : TAG_HEIGHT)
        .background(tag.color.opacity(0.1))
        .cornerRadius(isLargeDevice ? 12 : 8)
        .overlay(
            RoundedRectangle(cornerRadius: isLargeDevice ? 12 : 8)
                .stroke(tag.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AddTagButtonView: View {
    let onTap: () -> Void
    let isLargeDevice: Bool

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: isLargeDevice ? 6 : 4) {
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(isLargeDevice ? .title : .title3)
                    .foregroundColor(.blue)
                Spacer()
            }
            .frame(height: isLargeDevice ? 70 : TAG_HEIGHT)
            .frame(minWidth: isLargeDevice ? 32 : 24)
            .padding(.horizontal, isLargeDevice ? 16 : 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(isLargeDevice ? 12 : 8)
            .overlay(
                RoundedRectangle(cornerRadius: isLargeDevice ? 12 : 8)
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
                // Tag Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag Name")
                        .font(.headline)
                    
                    TextField("Enter tag name", text: $splitViewModel.editingTagName)
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
                                        .stroke(splitViewModel.editingTagColor == color ? Color.black : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    splitViewModel.editingTagColor = color
                                }
                        }
                    }
                }
                
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
                        splitViewModel.updateTag()
                    }
                    .disabled(splitViewModel.editingTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
} 
