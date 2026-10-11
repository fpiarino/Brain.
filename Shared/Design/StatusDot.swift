import SwiftUI

/// Il pallino di un giorno. Ogni stato ha forma e simbolo propri, non solo il colore:
/// - fatto: cerchio verde pieno con ✓
/// - non fatto: cerchio rosso pieno con ✗
/// - pausa: cerchio grigio-blu pieno con ‖
/// - non registrato: anello grigio vuoto
struct StatusDot: View {
    let status: DayStatus?
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            switch status {
            case .done?:
                Circle().fill(Color.statusDone)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .heavy))
                    .foregroundStyle(Color.onStatus)
            case .missed?:
                Circle().fill(Color.statusMissed)
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.4, weight: .heavy))
                    .foregroundStyle(Color.onStatus)
            case .paused?:
                Circle().fill(Color.statusPaused)
                Image(systemName: "pause.fill")
                    .font(.system(size: size * 0.38, weight: .heavy))
                    .foregroundStyle(Color.onStatus)
            case nil:
                Circle().strokeBorder(Color.statusEmpty, lineWidth: max(1.5, size * 0.06))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Riquadro arrotondato con l'emoji dell'obiettivo su sfondo del suo colore.
struct GoalChip: View {
    let emoji: String
    let color: GoalColor
    var size: CGFloat = 40

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(color.softBackground, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview("Pallini") {
    HStack(spacing: 16) {
        StatusDot(status: .done)
        StatusDot(status: .missed)
        StatusDot(status: .paused)
        StatusDot(status: nil)
        GoalChip(emoji: "🥗", color: .orange)
    }
    .padding()
}
