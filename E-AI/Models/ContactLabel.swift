// ContactLabel.swift
// Custom label model for contacts and companies

import Foundation
import SwiftUI

struct ContactLabel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        color: String = "#3B82F6",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
    
    // Convert hex color to SwiftUI Color
    var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
    
    // Predefined color palette (Trello-inspired)
    static let colorPalette: [(name: String, hex: String)] = [
        ("Red", "#EF5350"),
        ("Orange", "#FF9800"),
        ("Yellow", "#FFEE58"),
        ("Lime", "#9CCC65"),
        ("Green", "#66BB6A"),
        ("Teal", "#26A69A"),
        ("Blue", "#42A5F5"),
        ("Purple", "#AB47BC"),
        ("Pink", "#EC407A"),
        ("Gray", "#78909C")
    ]
}

// MARK: - Color Extension for Hex Conversion

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
