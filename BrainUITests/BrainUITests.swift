import XCTest

/// Verifica i criteri di successo dall'interfaccia, con un database vuoto in memoria
/// (argomento di avvio `-uiTesting`: niente dati reali, niente promemoria, niente Apple Salute).
final class BrainUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Limite di tempo per "crea e segna". 30 secondi sul Mac; sui server di GitHub,
    /// dove il simulatore è molto più lento, il workflow lo alza con
    /// `TEST_RUNNER_BRAIN_UI_TIME_LIMIT`.
    private var timeLimit: TimeInterval {
        ProcessInfo.processInfo.environment["BRAIN_UI_TIME_LIMIT"].flatMap(TimeInterval.init) ?? 30
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    /// Crea un obiettivo e lo segna come fatto: 3 tocchi più il nome.
    /// Restituisce i secondi impiegati.
    @discardableResult
    private func createGoalAndMarkDone(named name: String) -> TimeInterval {
        let newGoal = app.buttons["newGoalButton"]
        XCTAssertTrue(newGoal.waitForExistence(timeout: 10))

        let start = Date()
        newGoal.tap()                                   // tocco 1

        let nameField = app.textFields["goalNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        app.buttons["saveGoalButton"].tap()             // tocco 2

        let done = app.buttons["done-\(name)"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()                                      // tocco 3

        let elapsed = Date().timeIntervalSince(start)
        print("Crea e segna \"\(name)\": \(String(format: "%.1f", elapsed)) s")
        return elapsed
    }

    /// Aspetta che il pulsante abbia lo stato atteso (lascia finire animazioni e aggiornamenti).
    private func assertSelected(_ element: XCUIElement, _ selected: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "isSelected == %@", NSNumber(value: selected))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter.wait(for: [expectation], timeout: 3) != .completed {
            print(app.debugDescription)
            XCTFail("\(element.identifier) dovrebbe essere \(selected ? "selezionato" : "non selezionato")", file: file, line: line)
        }
    }

    func testCreateGoalAndMarkDoneQuickly() {
        let elapsed = createGoalAndMarkDone(named: "Meno di 1800 kcal")
        XCTAssertLessThan(elapsed, timeLimit, "Creare e segnare un obiettivo ha richiesto \(Int(elapsed)) secondi")
        assertSelected(app.buttons["done-Meno di 1800 kcal"], true)
    }

    func testOneTapMarksAndSecondTapClears() {
        createGoalAndMarkDone(named: "Leggere")
        let done = app.buttons["done-Leggere"]
        let missed = app.buttons["missed-Leggere"]
        assertSelected(done, true)

        // Un tocco su ✗ cambia stato direttamente.
        missed.tap()
        assertSelected(missed, true)
        assertSelected(done, false)

        // Un secondo tocco riporta a "non registrato".
        missed.tap()
        assertSelected(missed, false)
        assertSelected(done, false)
    }

    func testUndoRestoresPreviousState() {
        createGoalAndMarkDone(named: "Camminare")
        let missed = app.buttons["missed-Camminare"]
        missed.tap()
        assertSelected(missed, true)

        let undo = app.buttons["undoButton"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()

        assertSelected(app.buttons["done-Camminare"], true)
        assertSelected(missed, false)
    }
}
