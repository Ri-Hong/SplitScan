import SwiftUI
import Combine

class SplitViewModel: ObservableObject {
    @Published var tags: [SplitTag] = SplitTag.createDefaultTags()
    @Published var itemAssignments: [UUID: Set<UUID>] = [:] // itemId -> Set of tagIds
    @Published var showingAddTagSheet = false
    @Published var newTagName = ""
    @Published var selectedColor: Color = .blue
    @Published var editingTag: SplitTag?
    @Published var editingTagName = ""
    @Published var editingTagColor: Color = .blue
    
    private let maxTags = 5
    
    var canAddMoreTags: Bool {
        return tags.count < maxTags
    }
    
    func addTag() {
        guard canAddMoreTags && !newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let newTag = SplitTag(name: newTagName.trimmingCharacters(in: .whitespacesAndNewlines), color: selectedColor)
        tags.append(newTag)
        
        // Reset form
        newTagName = ""
        selectedColor = .blue
        showingAddTagSheet = false
    }
    
    func startEditingTag(_ tag: SplitTag) {
        editingTag = tag
        editingTagName = tag.name
        editingTagColor = tag.color
    }
    
    func updateTag() {
        guard let editingTag = editingTag,
              !editingTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        if let index = tags.firstIndex(where: { $0.id == editingTag.id }) {
            tags[index].name = editingTagName.trimmingCharacters(in: .whitespacesAndNewlines)
            tags[index].color = editingTagColor
        }
        
        // Reset editing state
        self.editingTag = nil
        editingTagName = ""
        editingTagColor = .blue
    }
    
    func cancelEditingTag() {
        editingTag = nil
        editingTagName = ""
        editingTagColor = .blue
    }
    
    func removeTag(_ tag: SplitTag) {
        // Remove tag from all item assignments
        for itemId in itemAssignments.keys {
            itemAssignments[itemId]?.remove(tag.id)
        }
        
        // Remove tag from tags array
        tags.removeAll { $0.id == tag.id }
    }
    
    func toggleItemAssignment(itemId: UUID, tagId: UUID) {
        if itemAssignments[itemId] == nil {
            itemAssignments[itemId] = Set<UUID>()
        }
        
        if itemAssignments[itemId]!.contains(tagId) {
            itemAssignments[itemId]!.remove(tagId)
        } else {
            itemAssignments[itemId]!.insert(tagId)
        }
    }
    
    func isItemAssignedToTag(itemId: UUID, tagId: UUID) -> Bool {
        return itemAssignments[itemId]?.contains(tagId) ?? false
    }
    
    func getAssignedTagsForItem(itemId: UUID) -> [SplitTag] {
        let assignedTagIds = itemAssignments[itemId] ?? Set<UUID>()
        return tags.filter { assignedTagIds.contains($0.id) }
    }
    
    func getTotalForTag(_ tag: SplitTag, items: [ReceiptItem]) -> Decimal {
        var total: Decimal = 0
        
        // Add explicitly assigned items
        for item in items {
            if isItemAssignedToTag(itemId: item.id, tagId: tag.id) {
                let itemPrice = item.isTaxed ? item.price * TAX_RATE : item.price
                total += itemPrice
            }
        }
        
        // Add default split from unassigned items
        let unassignedItems = getUnassignedItems(items: items)
        if !unassignedItems.isEmpty && !tags.isEmpty {
            let unassignedTotal = unassignedItems.reduce(Decimal(0)) { total, item in
                total + (item.isTaxed ? item.price * TAX_RATE : item.price)
            }
            let defaultSplitPerTag = unassignedTotal / Decimal(tags.count)
            total += defaultSplitPerTag
        }
        
        return total
    }
    
    func getUnassignedItems(items: [ReceiptItem]) -> [ReceiptItem] {
        return items.filter { item in
            let assignedTags = getAssignedTagsForItem(itemId: item.id)
            return assignedTags.isEmpty
        }
    }
    
    func getUnassignedTotal(items: [ReceiptItem]) -> Decimal {
        let unassignedItems = getUnassignedItems(items: items)
        return unassignedItems.reduce(Decimal(0)) { total, item in
            total + (item.isTaxed ? item.price * TAX_RATE : item.price)
        }
    }
    
    func getDefaultSplitPerTag(items: [ReceiptItem]) -> Decimal {
        let unassignedTotal = getUnassignedTotal(items: items)
        return tags.isEmpty ? 0 : unassignedTotal / Decimal(tags.count)
    }
}

// Constants
private let TAX_RATE: Decimal = 1.13 
