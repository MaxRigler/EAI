// CRMContact.swift
// Business contact linked to Apple Contacts

import Foundation

/// Box wrapper to enable recursive reference in value types
final class ContactBox: Equatable, Hashable {
    var contact: CRMContact?
    
    init(_ contact: CRMContact? = nil) {
        self.contact = contact
    }
    
    static func == (lhs: ContactBox, rhs: ContactBox) -> Bool {
        lhs.contact?.id == rhs.contact?.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(contact?.id)
    }
}

struct CRMContact: Identifiable, Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CRMContact, rhs: CRMContact) -> Bool {
        lhs.id == rhs.id
    }
    
    let id: UUID
    var appleContactId: String?
    var name: String
    var email: String?
    var phone: String?
    var businessType: String?
    var company: String?
    var domain: String?
    var dealStage: String?
    var tags: [String]
    var customFields: [String: String]
    var isCompany: Bool
    var companyId: UUID?
    let createdAt: Date
    var updatedAt: Date?
    
    // Transient property (not stored in DB, used for UI) - uses box to avoid recursive struct issue
    private var _companyContactBox: ContactBox = ContactBox()
    
    var companyContact: CRMContact? {
        get { _companyContactBox.contact }
        set { _companyContactBox.contact = newValue }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case appleContactId = "apple_contact_id"
        case name
        case email
        case phone
        case businessType = "business_type"
        case company
        case domain
        case dealStage = "deal_stage"
        case tags
        case customFields = "custom_fields"
        case isCompany = "is_company"
        case companyId = "company_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        appleContactId: String? = nil,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        businessType: String? = nil,
        company: String? = nil,
        domain: String? = nil,
        dealStage: String? = nil,
        tags: [String] = [],
        customFields: [String: String] = [:],
        isCompany: Bool = false,
        companyId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        companyContact: CRMContact? = nil
    ) {
        self.id = id
        self.appleContactId = appleContactId
        self.name = name
        self.email = email
        self.phone = phone
        self.businessType = businessType
        self.company = company
        self.domain = domain
        self.dealStage = dealStage
        self.tags = tags
        self.customFields = customFields
        self.isCompany = isCompany
        self.companyId = companyId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self._companyContactBox = ContactBox(companyContact)
    }
}
