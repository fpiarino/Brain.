import Foundation
import SwiftData

/// Richieste al database usate da `@Query`.
/// Tipi espliciti e passaggi separati: scritte in linea dentro `@Query(...)`
/// il compilatore impiega troppo a verificarle.
enum GoalQueries {
    static let activePredicate: Predicate<Goal> = #Predicate<Goal> { goal in
        goal.archivedAt == nil
    }

    static let archivedPredicate: Predicate<Goal> = #Predicate<Goal> { goal in
        goal.archivedAt != nil
    }

    /// Obiettivi attivi nell'ordine scelto dall'utente.
    static var active: FetchDescriptor<Goal> {
        let order: [SortDescriptor<Goal>] = [
            SortDescriptor(\Goal.sortOrder),
            SortDescriptor(\Goal.createdAt)
        ]
        return FetchDescriptor<Goal>(predicate: activePredicate, sortBy: order)
    }

    /// Obiettivi archiviati, dal più recente.
    static var archived: FetchDescriptor<Goal> {
        let order: [SortDescriptor<Goal>] = [
            SortDescriptor(\Goal.archivedAt, order: .reverse)
        ]
        return FetchDescriptor<Goal>(predicate: archivedPredicate, sortBy: order)
    }
}
