// ContactRepository.swift
// CRUD for CRM contacts

import Foundation

class ContactRepository {
    
    func fetchAllContacts() async throws -> [CRMContact] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    func fetchContact(id: UUID) async throws -> CRMContact? {
        guard let client = await SupabaseManager.shared.getClient() else {
            return nil
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    func searchContacts(query: String) async throws -> [CRMContact] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .ilike("name", pattern: "%\(query)%")
            .order("name")
            .limit(50)
            .execute()
            .value
        
        return response
    }
    
    func createContact(_ contact: CRMContact) async throws -> CRMContact {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .insert(contact)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    func updateContact(_ contact: CRMContact) async throws -> CRMContact {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .update(contact)
            .eq("id", value: contact.id.uuidString)
            .select()
            .execute()
            .value
        
        guard let updated = response.first else {
            throw RepositoryError.updateFailed
        }
        
        return updated
    }
    
    // MARK: - Company-Related Queries
    
    /// Fetch only company contacts (is_company = true)
    func fetchCompanies() async throws -> [CRMContact] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .eq("is_company", value: true)
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    /// Fetch only individual contacts (not companies)
    func fetchPeople() async throws -> [CRMContact] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .or("is_company.eq.false,is_company.is.null")
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    /// Fetch contacts that belong to a specific company
    func fetchContactsForCompany(companyId: UUID) async throws -> [CRMContact] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    /// Fetch a contact with its associated company contact populated
    func fetchContactWithCompany(id: UUID) async throws -> CRMContact? {
        guard var contact = try await fetchContact(id: id) else {
            return nil
        }
        
        // If contact has a company_id, fetch the company contact
        if let companyId = contact.companyId {
            contact.companyContact = try await fetchContact(id: companyId)
        }
        
        return contact
    }
}

