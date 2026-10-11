import SwiftUI

/// Riepilogo della giornata: data, barra a segmenti (uno per obiettivo) e conteggi.
struct TodaySummaryCard: View {
    let today: DayKey
    /// Stato di oggi di ogni obiettivo registrabile (fatto, non fatto, pausa o aperto).
    let indicators: [DayStatus?]
    /// Obiettivi che aspettano ancora una registrazione a mano.
    let pendingCount: Int

    init(today: DayKey, indicators: [DayStatus?], pendingCount: Int) {
        self.today = today
        self.indicators = indicators
        self.pendingCount = pendingCount
    }

    private func count(_ status: DayStatus) -> Int { indicators.filter { $0 == status }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ItalianFormat.weekdayTitle(today))
                .font(.subheadline.weight(.semibold))

            if !indicators.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(indicators.enumerated()), id: \.offset) { _, status in
                        Capsule()
                            .fill(color(for: status))
                            .frame(height: 8)
                    }
                }
            }

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ItalianFormat.weekdayTitle(today)). \(summaryText)")
    }

    private var summaryText: String {
        guard !indicators.isEmpty else { return "Nessun obiettivo da registrare oggi" }
        let done = count(.done)
        let missed = count(.missed)
        let paused = count(.paused)

        var parts = [
            "\(done) \(done == 1 ? "fatto" : "fatti")",
            "\(missed) \(missed == 1 ? "non fatto" : "non fatti")"
        ]
        if paused > 0 { parts.append("\(paused) in pausa") }
        if pendingCount > 0 {
            parts.append("\(pendingCount) da registrare")
        } else {
            parts.insert("Tutto registrato:", at: 0)
            return parts[0] + " " + parts.dropFirst().joined(separator: " · ")
        }
        return parts.joined(separator: " · ")
    }

    private func color(for status: DayStatus?) -> Color {
        switch status {
        case .done?: .statusDone
        case .missed?: .statusMissed
        case .paused?: .statusPaused
        case nil: Color(uiColor: .systemGray5)
        }
    }
}
