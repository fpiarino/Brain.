import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Esporta tutti i dati in un file JSON (da salvare in File o iCloud Drive)
/// e li ripristina da un file esportato in precedenza.
struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImport: BackupFile?
    @State private var message: String?

    init() {}

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Esporta backup", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Crea un file con tutti gli obiettivi, i giorni registrati e le note. Salvalo in iCloud Drive o in un'altra cartella di File: i dati di Brain altrimenti esistono solo su questo iPhone.")
                }

                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Ripristina da un backup", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("Sostituisce tutti i dati attuali con quelli del file scelto.")
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Backup e ripristino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: BackupCodec.suggestedFileName(for: .today())
            ) { result in
                switch result {
                case .success:
                    message = "Backup salvato."
                case .failure(let error):
                    message = "Salvataggio non riuscito: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                readBackup(result)
            }
            .confirmationDialog(
                "Sostituire tutti i dati?",
                isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                titleVisibility: .visible,
                presenting: pendingImport
            ) { file in
                Button("Sostituisci con il backup", role: .destructive) {
                    modelContext.replaceAll(with: file)
                    message = "Ripristinati \(file.goals.count) obiettivi dal backup del \(ItalianFormat.fullDateText(DayKey(file.exportedAt)))."
                    pendingImport = nil
                    Task { await ReminderScheduler.reschedule(using: modelContext) }
                }
                Button("Annulla", role: .cancel) { pendingImport = nil }
            } message: { file in
                let entries = file.goals.reduce(0) { $0 + $1.entries.count }
                Text("Il backup contiene \(file.goals.count) obiettivi e \(entries) giorni registrati. I dati attuali verranno eliminati.")
            }
        }
    }

    private func prepareExport() {
        do {
            let data = try BackupCodec.encode(modelContext.makeBackup())
            exportDocument = BackupDocument(data: data)
            showingExporter = true
        } catch {
            message = "Impossibile creare il backup: \(error.localizedDescription)"
        }
    }

    private func readBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pendingImport = try BackupCodec.decode(data)
            } catch {
                message = (error as? LocalizedError)?.errorDescription ?? "Impossibile leggere il file: \(error.localizedDescription)"
            }
        case .failure(let error):
            message = "Impossibile aprire il file: \(error.localizedDescription)"
        }
    }
}

/// File JSON di backup per `fileExporter`.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
