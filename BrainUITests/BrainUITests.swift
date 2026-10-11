import XCTest

/// Verifica i criteri di successo dall'interfaccia, con un database vuoto in memoria
/// (argomento di avvio `-uiTesting`: niente dati reali, niente promemoria, niente Apple Salute).
final class BrainUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    /// Crea un obiettivo e lo segna come fatto. Restituisce i secondi impiegati.
    @discardableResult
    private func createGoalAndMarkDone(named name: String) -> TimeInterval {
        let start = Date()

        let newGoal = app.buttons["newGoalButton"]
        XCTAssertTrue(newGoal.waitForExistence(timeout: 5))
        newGoal.tap()

        let nameField = app.textFields["goalNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        app.buttons["saveGoalButton"].tap()

        let done = app.buttons["done-\(name)"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        return Date().timeIntervalSince(start)
    }

    func testCreateGoalAndMarkDoneInUnder30Seconds() {
        let elapsed = createGoalAndMarkDone(named: "Meno di 1800 kcal")
        XCTAssertLessThan(elapsed, 30, "Creare e segnare un obiettivo ha richiesto \(Int(elapsed)) secondi")
        XCTAssertTrue(app.buttons["done-Meno di 1800 kcal"].isSelected)
    }

    func testOneTapMarksAndSecondTapClears() {
        createGoalAndMarkDone(named: "Leggere")
        let done = app.buttons["done-Leggere"]
        let missed = app.buttons["missed-Leggere"]
        XCTAssertTrue(done.isSelected)

        // Un tocco su ✗ cambia stato direttamente.
        missed.tap()
        XCTAssertTrue(missed.isSelected)
        XCTAssertFalse(done.isSelected)

        // Un secondo tocco riporta a "non registrato".
        missed.tap()
        XCTAssertFalse(missed.isSelected)
        XCTAssertFalse(done.isSelected)
    }

    func testUndoRestoresPreviousState() {
        createGoalAndMarkDone(named: "Camminare")
        let missed = app.buttons["missed-Camminare"]
        missed.tap()
        XCTAssertTrue(missed.isSelected)

        let undo = app.buttons["undoButton"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()

        XCTAssertTrue(app.buttons["done-Camminare"].isSelected)
        XCTAssertFalse(missed.isSelected)
    }
}
