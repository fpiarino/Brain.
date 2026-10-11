# Brain v2 — Nota delle decisioni

## Architettura
- **SwiftUI + SwiftData**, iOS 17+, solo iPhone, nessuna libreria esterna, nessun server né account. Swift 5 come modalità di linguaggio: il passaggio a Swift 6 è rimandato a quando il progetto compila sul Mac.
- **Quattro target**: app `Brain`, widget `BrainWidgetExtension`, test unitari `BrainTests`, test dell'interfaccia `BrainUITests`.
- **Cartella `Shared/`** compilata sia nell'app sia nel widget: logica, modello dati, database condiviso, colori, azione del widget.
- **Logica pura in `Shared/Logic/`** (giorni, serie, settimane, statistiche, backup, promemoria): non tocca database né orologio, quindi è coperta interamente dai test.
- **Tutte le scritture** passano da `ModelContext+Goals.swift`: una registrazione per giorno, salvataggio esplicito, aggiornamento del widget.

## Modello dati
- `Goal`: nome, descrizione, emoji, colore, data di inizio, archiviazione, ordine; dalla v2 anche **tipo** (Sì/No, a settimana, numerico), volte a settimana, soglia, confronto (al massimo / almeno), unità, dato di Apple Salute.
- `DayEntry`: giorno `yyyymmdd`, stato (fatto / non fatto / **pausa**), **valore**, **nota**, provenienza da Salute.
- "Non registrato" = nessuno stato e nessun valore. I campi nuovi hanno valori predefiniti: i dati della v1 si aggiornano da soli.

## Regole di calcolo
- Contano solo i giorni dalla data di inizio a oggi. Percentuale = fatti ÷ (fatti + non fatti).
- **Pausa**: fuori dalla percentuale, non interrompe la serie e non la allunga. Un giorno passato non registrato invece la interrompe.
- **Settimanali**: la settimana (lun–dom) riesce con N giorni fatti. Se i giorni disponibili (dopo l'inizio, non in pausa) sono meno di N, l'obiettivo scende. Una settimana in corso non interrompe la serie.
- **Numerici**: fatto se il valore rispetta la soglia. Un valore da Salute per oggi è parziale: diventa fatto appena una soglia "almeno" è raggiunta, altrimenti si decide a fine giornata. Un valore inserito a mano vince sempre su Salute.

## Scelte UX
- **Oggi**: ✗ / ✓ con un tocco (solo ✓ per i settimanali, un pulsante valore per i numerici). Ogni tocco mostra "Annulla" per 5 secondi.
- **Giorno**: dal calendario si registra, si corregge, si mette in pausa e si scrive una nota.
- **Statistiche**: mappa dell'anno e successo per giorno della settimana, con il giorno più difficile evidenziato.
- **Accessibilità**: ogni stato ha forma e simbolo propri (● ✓, ● ✗, ● ‖, ○), anche nella mappa dell'anno. Etichette VoiceOver complete. Con testo molto grande i controlli vanno a capo.

## Dati condivisi con il widget
- Il database sta nel contenitore dell'**App Group** `group.<identificativo app>`. Alla prima apertura della v2 l'app copia lì il database della v1, che resta come copia di sicurezza.
- I pulsanti del widget scrivono nel database da un altro processo. Al ritorno in primo piano l'app riapre il database e riparte dalla schermata Oggi, così non mostra mai dati vecchi.
- Se l'App Group non è disponibile, l'app funziona col percorso della v1 e il widget invita ad aprire l'app.

## Promemoria
Una notifica locale per ogni obiettivo da registrare, con le risposte direttamente nella notifica: ✓ / ✗, oppure il valore. Il piano copre fino a 14 giorni, entro il limite di 64 notifiche di iOS, e si ricalcola a ogni apertura dell'app.

## Limiti dell'Apple ID gratuito
- **iCloud non è disponibile**: al suo posto c'è il backup manuale in un file JSON da salvare in File o iCloud Drive.
- **App Groups e HealthKit** funzionano con il team personale. Se la firma li rifiuta, il README spiega come disattivarli.

## Accortezze per SwiftData su iOS 17
- `#Unique` esiste solo da iOS 18: l'unicità giorno/obiettivo la garantisce il codice.
- La cancellazione a cascata è poco affidabile: le registrazioni vengono eliminate esplicitamente.
- Prima si inserisce un oggetto nel database, poi lo si collega all'obiettivo.
