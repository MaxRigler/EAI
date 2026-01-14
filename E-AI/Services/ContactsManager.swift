// ContactsManager.swift
// Apple Contacts.framework wrapper

import Foundation
import Contacts

@MainActor
class ContactsManager: ObservableObject {
    static let shared = ContactsManager()
    
    @Published private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published private(set) var contacts: [CNContact] = []
    @Published private(set) var error: Error?
    
    private let store = CNContactStore()
    
    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor
    ]
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            checkAuthorizationStatus()
            return granted
        } catch {
            self.error = error
            return false
        }
    }
    
    // MARK: - Fetch Contacts
    
    func fetchAllContacts() async throws -> [CNContact] {
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        var allContacts: [CNContact] = []
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName
        
        try store.enumerateContacts(with: request) { contact, _ in
            allContacts.append(contact)
        }
        
        contacts = allContacts
        return allContacts
    }
    
    func searchContacts(query: String) async throws -> [CNContact] {
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        guard !query.isEmpty else {
            return contacts
        }
        
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let results = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        
        return results
    }
    
    func getContact(withIdentifier identifier: String) throws -> CNContact? {
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        return try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
    }
    
    // MARK: - Create Contact
    
    func createContact(
        firstName: String,
        lastName: String,
        email: String?,
        phone: String?,
        company: String?
    ) async throws -> CNContact {
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        let newContact = CNMutableContact()
        newContact.givenName = firstName
        newContact.familyName = lastName
        
        if let email = email, !email.isEmpty {
            newContact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: email as NSString)
            ]
        }
        
        if let phone = phone, !phone.isEmpty {
            newContact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))
            ]
        }
        
        if let company = company, !company.isEmpty {
            newContact.organizationName = company
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(newContact, toContainerWithIdentifier: nil)
        
        try store.execute(saveRequest)
        
        // Fetch the newly created contact
        let createdContact = try store.unifiedContact(withIdentifier: newContact.identifier, keysToFetch: keysToFetch)
        return createdContact
    }
    
    // MARK: - Update Contact
    
    func updateContact(_ contact: CNContact, updates: ContactUpdates) async throws -> CNContact {
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        guard let mutableContact = contact.mutableCopy() as? CNMutableContact else {
            throw ContactsError.updateFailed
        }
        
        if let firstName = updates.firstName {
            mutableContact.givenName = firstName
        }
        
        if let lastName = updates.lastName {
            mutableContact.familyName = lastName
        }
        
        if let company = updates.company {
            mutableContact.organizationName = company
        }
        
        // Update email
        if let email = updates.email {
            if email.isEmpty {
                mutableContact.emailAddresses = []
            } else {
                mutableContact.emailAddresses = [
                    CNLabeledValue(label: CNLabelWork, value: email as NSString)
                ]
            }
        }
        
        // Update phone
        if let phone = updates.phone {
            if phone.isEmpty {
                mutableContact.phoneNumbers = []
            } else {
                mutableContact.phoneNumbers = [
                    CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))
                ]
            }
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)
        
        try store.execute(saveRequest)
        
        return try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch)
    }
}

// MARK: - Contact Updates

struct ContactUpdates {
    var firstName: String?
    var lastName: String?
    var company: String?
    var email: String?
    var phone: String?
}

// MARK: - CNContact Extension

extension CNContact {
    var fullName: String {
        let formatter = CNContactFormatter()
        return formatter.string(from: self) ?? "\(givenName) \(familyName)"
    }
    
    var primaryEmail: String? {
        emailAddresses.first?.value as String?
    }
    
    var primaryPhone: String? {
        phoneNumbers.first?.value.stringValue
    }
}

// MARK: - Contacts Error

enum ContactsError: LocalizedError {
    case notAuthorized
    case createFailed
    case updateFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Contacts access not authorized. Please grant permission in System Settings."
        case .createFailed:
            return "Failed to create contact"
        case .updateFailed:
            return "Failed to update contact"
        case .notFound:
            return "Contact not found"
        }
    }
}
