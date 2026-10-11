import SwiftUI
import UIKit

extension Color {
    /// Colore con varianti per modalità chiara e scura.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Tinta dell'app (pulsanti, link, oggi nel calendario).
    static let brainTint = Color(light: 0x2F5BEA, dark: 0x7C95FF)
    /// Pallino verde: fatto. Più scuro del verde di sistema per avere contrasto con il bianco.
    static let statusDone = Color(light: 0x1E8E3E, dark: 0x30D158)
    /// Pallino rosso: non fatto.
    static let statusMissed = Color(light: 0xD93025, dark: 0xFF453A)
    /// Simbolo sopra i pallini pieni (bianco in chiaro, nero in scuro, per il contrasto).
    static let onStatus = Color(light: 0xFFFFFF, dark: 0x000000)
    /// Pallino dei giorni in pausa: neutro, distinto dal grigio dei giorni vuoti.
    static let statusPaused = Color(light: 0x5B6B8C, dark: 0x8FA0C2)
    /// Anello dei giorni non registrati.
    static let statusEmpty = Color(light: 0x8E8E93, dark: 0x8E8E93)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Gli 8 colori disponibili per gli obiettivi. Niente rosso e niente verde,
/// per non confonderli con i pallini fatto / non fatto.
enum GoalColor: String, CaseIterable, Identifiable {
    case blue, teal, purple, pink, orange, mustard, brown, graphite

    var id: String { rawValue }

    var name: String {
        switch self {
        case .blue: "Blu"
        case .teal: "Verde acqua"
        case .purple: "Viola"
        case .pink: "Rosa"
        case .orange: "Arancione"
        case .mustard: "Senape"
        case .brown: "Marrone"
        case .graphite: "Grafite"
        }
    }

    var color: Color {
        switch self {
        case .blue: Color(light: 0x2F5BEA, dark: 0x6E8CFF)
        case .teal: Color(light: 0x0E8C8C, dark: 0x3CC4C4)
        case .purple: Color(light: 0x7B4FD6, dark: 0xA889F0)
        case .pink: Color(light: 0xD6457A, dark: 0xF27BA6)
        case .orange: Color(light: 0xE07A1F, dark: 0xF5A04F)
        case .mustard: Color(light: 0xB8860B, dark: 0xE0B53A)
        case .brown: Color(light: 0x8A6A4F, dark: 0xB89A7E)
        case .graphite: Color(light: 0x5A5F6B, dark: 0x9EA3AE)
        }
    }

    /// Sfondo tenue per il riquadro dell'emoji.
    var softBackground: Color { color.opacity(0.18) }

    /// Colore assegnato a rotazione al nuovo obiettivo numero `index`.
    static func rotating(_ index: Int) -> GoalColor {
        let all = GoalColor.allCases
        return all[((index % all.count) + all.count) % all.count]
    }
}
