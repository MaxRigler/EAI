// LabelRepository.swift
// CRUD operations for labels and label assignments

import Foundation

class LabelRepository {
    
    // MARK: - Label CRUD
    
    /// Fetch all available labels
    func fetchAllLabels() async throws -> [ContactLabel] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [ContactLabel] = try await client
            .from("contact_labels")
            .select()
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    /// Create a new label
    func createLabel(_ label: ContactLabel) async throws -> ContactLabel {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [ContactLabel] = try await client
            .from("contact_labels")
            .insert(label)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    /// Update an existing label
    func updateLabel(_ label: ContactLabel) async throws -> ContactLabel {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [ContactLabel] = try await client
            .from("contact_labels")
            .update(label)
            .eq("id", value: label.id.uuidString)
            .select()
            .execute()
            .value
        
        guard let updated = response.first else {
            throw RepositoryError.updateFailed
        }
        
        return updated
    }
    
    /// Delete a label (cascades to assignments)
    func deleteLabel(id: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        try await client
            .from("contact_labels")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Label Assignments
    
    /// Fetch labels for a specific contact
    func fetchLabelsForContact(contactId: UUID) async throws -> [ContactLabel] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        // Join through the assignment table to get full label details
        struct AssignmentWithLabel: Codable {
            let labelId: UUID
            let contactLabels: ContactLabel
            
            enum CodingKeys: String, CodingKey {
                case labelId = "label_id"
                case contactLabels = "contact_labels"
            }
        }
        
        let response: [AssignmentWithLabel] = try await client
            .from("contact_label_assignments")
            .select("label_id, contact_labels(*)")
            .eq("contact_id", value: contactId.uuidString)
            .execute()
            .value
        
        return response.map { $0.contactLabels }
    }
    
    /// Assign a label to a contact
    func assignLabel(labelId: UUID, contactId: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let assignment = ContactLabelAssignment(
            labelId: labelId,
            contactId: contactId
        )
        
        // Use upsert to handle duplicate gracefully
        try await client
            .from("contact_label_assignments")
            .upsert(assignment, onConflict: "label_id,contact_id")
            .execute()
        
        print("LabelRepository: Assigned label \(labelId) to contact \(contactId)")
    }
    
    /// Remove a label from a contact
    func removeLabel(labelId: UUID, contactId: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        try await client
            .from("contact_label_assignments")
            .delete()
            .eq("label_id", value: labelId.uuidString)
            .eq("contact_id", value: contactId.uuidString)
            .execute()
        
        print("LabelRepository: Removed label \(labelId) from contact \(contactId)")
    }
    
    // MARK: - Label Propagation
    
    /// Propagate a contact's labels to its associated company
    func propagateLabelsToCompany(contactId: UUID, companyId: UUID) async throws {
        // Get all labels from the contact
        let contactLabels = try await fetchLabelsForContact(contactId: contactId)
        
        // Assign each label to the company (upsert handles duplicates)
        for label in contactLabels {
            try await assignLabel(labelId: label.id, contactId: companyId)
        }
        
        print("LabelRepository: Propagated \(contactLabels.count) labels from contact \(contactId) to company \(companyId)")
    }
    
    /// Propagate a company's labels to all associated contacts
    func propagateLabelsToContacts(companyId: UUID, contactRepository: ContactRepository) async throws {
        // Get all labels from the company
        let companyLabels = try await fetchLabelsForContact(contactId: companyId)
        
        // Get all contacts associated with this company
        let associatedContacts = try await contactRepository.fetchContactsForCompany(companyId: companyId)
        
        // Assign each label to each contact (upsert handles duplicates)
        for contact in associatedContacts {
            for label in companyLabels {
                try await assignLabel(labelId: label.id, contactId: contact.id)
            }
        }
        
        print("LabelRepository: Propagated \(companyLabels.count) labels from company \(companyId) to \(associatedContacts.count) contacts")
    }
    
    /// Propagate a single label to related entities based on contact type
    func propagateLabelAssignment(label: ContactLabel, contact: CRMContact, contactRepository: ContactRepository) async throws {
        if contact.isCompany {
            // Company: propagate to all associated contacts
            let associatedContacts = try await contactRepository.fetchContactsForCompany(companyId: contact.id)
            for associatedContact in associatedContacts {
                try await assignLabel(labelId: label.id, contactId: associatedContact.id)
            }
            print("LabelRepository: Propagated label '\(label.name)' to \(associatedContacts.count) associated contacts")
        } else if let companyId = contact.companyId {
            // Individual: propagate to company
            try await assignLabel(labelId: label.id, contactId: companyId)
            print("LabelRepository: Propagated label '\(label.name)' to associated company \(companyId)")
        }
    }
    
    // MARK: - Filtering Support (for future use)
    
    /// Fetch all contacts that have a specific label
    func fetchContactsWithLabel(labelId: UUID) async throws -> [UUID] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        struct AssignmentContactId: Codable {
            let contactId: UUID
            
            enum CodingKeys: String, CodingKey {
                case contactId = "contact_id"
            }
        }
        
        let response: [AssignmentContactId] = try await client
            .from("contact_label_assignments")
            .select("contact_id")
            .eq("label_id", value: labelId.uuidString)
            .execute()
            .value
        
        return response.map { $0.contactId }
    }
    
    /// Fetch contacts with any of the specified labels
    func fetchContactsWithLabels(labelIds: [UUID]) async throws -> [UUID] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        struct AssignmentContactId: Codable {
            let contactId: UUID
            
            enum CodingKeys: String, CodingKey {
                case contactId = "contact_id"
            }
        }
        
        let labelIdStrings = labelIds.map { $0.uuidString }
        
        let response: [AssignmentContactId] = try await client
            .from("contact_label_assignments")
            .select("contact_id")
            .in("label_id", values: labelIdStrings)
            .execute()
            .value
        
        // Return unique contact IDs
        return Array(Set(response.map { $0.contactId }))
    }
}
