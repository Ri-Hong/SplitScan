import SwiftUI

// Constants
private let TAX_RATE: Decimal = 1.13

struct SummaryView: View {
    let items: [ReceiptItem]
    @ObservedObject var splitViewModel: SplitViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Split Summary")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Here's what each person owes:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Individual Totals
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(splitViewModel.tags) { tag in
                            let total = splitViewModel.getTotalForTag(tag, items: items)
                            let assignedItems = getAssignedItemsForTag(tag)
                            
                            VStack(spacing: 12) {
                                // Person Header
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(tag.name)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "$%.2f", NSDecimalNumber(decimal: total).doubleValue))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                
                                // Assigned Items
                                if !assignedItems.isEmpty {
                                    VStack(spacing: 8) {
                                        ForEach(assignedItems, id: \.id) { item in
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
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.05))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                                
                                if assignedItems.isEmpty {
                                    Text("No items assigned")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                }
                            }
                            .padding()
                            .background(tag.color.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(tag.color.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Shared Default Split Section
                        let defaultSplit = splitViewModel.getDefaultSplitPerTag(items: items)
                        let unassignedItems = splitViewModel.getUnassignedItems(items: items)
                        
                        if defaultSplit > 0 && !unassignedItems.isEmpty {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    
                                    Text("Shared Items")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "$%.2f", NSDecimalNumber(decimal: defaultSplit).doubleValue))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                
                                Text("Split equally between all \(splitViewModel.tags.count) people")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    ForEach(unassignedItems, id: \.id) { item in
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
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Grand Total
                let grandTotal = items.reduce(Decimal(0)) { $0 + ($1.isTaxed ? $1.price * TAX_RATE : $1.price) }
                
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack {
                        Text("Grand Total:")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(String(format: "$%.2f", NSDecimalNumber(decimal: grandTotal).doubleValue))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Summary")
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
    
    private func getAssignedItemsForTag(_ tag: SplitTag) -> [ReceiptItem] {
        return items.filter { item in
            splitViewModel.isItemAssignedToTag(itemId: item.id, tagId: tag.id)
        }
    }
} 
