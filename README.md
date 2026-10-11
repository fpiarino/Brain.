# Brain

App iPhone per tracciare obiettivi. Ogni giorno segni ciascun obiettivo come fatto (● ✓ verde), non fatto (● ✗ rosso) o in pausa (● ‖). Nel calendario di ogni obiettivo vedi i pallini del mese, i conteggi, la percentuale di successo e le serie.

**Novità della v2**
- Tre tipi di obiettivo:
  - **Sì / No**: ogni giorno segni fatto o non fatto.
  - **N volte a settimana**: per esempio palestra 3 volte.
  - **Numerico**: per esempio kcal ≤ 1800 o passi ≥ 10.000.
- **Apple Salute**: passi, calorie attive, calorie assunte e minuti di esercizio compilano da soli gli obiettivi numerici.
- **Widget** per la schermata Home e la schermata di blocco, con i pulsanti ✓ / ✗.
- **Promemoria serale** con le risposte direttamente nella notifica.
- **Giorni di pausa**, **note** per giorno, **Annulla** dopo ogni tocco, **riordino** degli obiettivi.
- **Statistiche**: mappa dell'anno e successo per giorno della settimana.
- **Backup e ripristino** in un file JSON.

Le scelte di progetto sono in [DECISIONI.md](DECISIONI.md).

---

## 1. Cosa ti serve

- Un **Mac** con **Xcode 16 o successivo**. Va bene anche l'ultima versione.
- Per il telefono: un **iPhone con iOS 17 o successivo**, un cavo e un **Apple ID** (va bene quello gratuito).

## 2. Aprire il progetto

1. Decomprimi `Brain.zip` e fai doppio clic su **`Brain.xcodeproj`**.
2. Se Xcode chiede di scaricare la piattaforma iOS o il simulatore, accetta.
3. In alto a sinistra, accanto al pulsante ▶︎, controlla che lo schema selezionato sia **Brain**.

## 3. Simulatore

1. Scegli un iPhone del simulatore come destinazione e premi **⌘R**.
2. **Widget:** tieni premuto sulla schermata Home del simulatore → **Modifica** → **Aggiungi widget** → cerca **Brain**.
3. **Apple Salute:** nel simulatore l'app Salute esiste ma è vuota. Per provare un obiettivo collegato, inserisci qualche dato a mano in Salute (es. *Passi*).

## 4. Test

Premi **⌘U**. Partono due gruppi di test:

- **BrainTests**: tutti i calcoli (conteggi, percentuali, serie, settimane, pause, numerici, statistiche, backup, promemoria).
- **BrainUITests**: i criteri di successo usati dall'interfaccia. Verificano che si crei e segni un obiettivo in meno di 30 secondi, che basti un tocco e che "Annulla" funzioni. Girano su un database vuoto in memoria e non toccano i tuoi dati.

Nel Test navigator (⌘6) devono risultare tutti verdi.

## 5. Installarla sul tuo iPhone con un Apple ID gratuito

**In Xcode, una volta sola:**

1. Menu **Xcode → Settings… → Accounts**, premi **+** e accedi con il tuo Apple ID.
2. Seleziona il progetto **Brain** (icona blu in cima al navigatore).
3. Per **entrambi** i target **Brain** e **BrainWidgetExtension**, apri la scheda **Signing & Capabilities**. Lascia attivo *Automatically manage signing* e scegli il tuo *Personal Team*.
4. **Identificativo unico:** sempre sul progetto, scheda **Build Settings**, cerca `BRAIN_BUNDLE_BASE`. Cambia `it.mioprogetto.brain` con qualcosa di tuo, ad esempio `it.tuonome.brain`. Basta cambiarlo lì: app, widget, test e App Group si aggiornano da soli.

**Sull'iPhone, una volta sola:**

5. Collega l'iPhone con il cavo, sbloccalo e tocca **Autorizza** quando chiede se fidarsi del Mac.
6. Attiva la **Modalità sviluppatore**: *Impostazioni → Privacy e sicurezza → Modalità sviluppatore*, poi riavvia. La voce compare dopo il primo collegamento con Xcode.

**Installazione:**

7. Scegli il tuo iPhone come destinazione e premi **⌘R**.
8. Se iOS blocca l'app come "sviluppatore non autorizzato": *Impostazioni → Generali → VPN e gestione dispositivi* → il tuo Apple ID → **Autorizza**.
9. Aggiungi il widget dalla schermata Home (tieni premuto → **Modifica** → **Aggiungi widget** → **Brain**).

**Se avevi già la v1 sul telefono:** dopo l'installazione apri prima l'app, poi aggiungi il widget. Al primo avvio Brain sposta i dati nello spazio condiviso con il widget. Il vecchio file resta come copia di sicurezza.

**Limiti dell'Apple ID gratuito:**

- L'app **scade dopo 7 giorni**. Per rinnovarla ricollega l'iPhone e premi ⌘R: i dati restano.
- Massimo 3 app installate così. Xcode può registrare al massimo 10 identificativi a settimana, e Brain ne usa 2 (app e widget): evita di cambiare `BRAIN_BUNDLE_BASE` troppe volte.
- **Niente sincronizzazione iCloud**: richiede l'account a pagamento. Usa il **backup** (menu **⋯** in alto a sinistra in *Oggi* → *Backup e ripristino*) e salva il file in iCloud Drive.
- Se elimini l'app dal telefono elimini anche i dati: fai prima un backup.

## 6. Se la firma o la compilazione falliscono

- **"Personal development teams do not support…" su App Groups o HealthKit.**
  1. Nella scheda *Signing & Capabilities* del target indicato, rimuovi la capability con la ✕.
  2. Senza **App Groups** il widget mostra "Apri Brain per iniziare", ma l'app funziona normalmente.
  3. Senza **HealthKit** non si possono collegare obiettivi ad Apple Salute; gli obiettivi numerici a mano funzionano lo stesso.
- **Errore di compilazione.** Il progetto è stato scritto senza poter compilare su un Mac. La logica è stata verificata a parte con 13.000 controlli automatici, ma la prima compilazione la fai tu.
  1. Apri il **Report navigator** (⌘9) e seleziona l'ultima build.
  2. Copia il messaggio di errore con file e riga.
  3. Mandamelo: lo correggo.

## 7. Struttura del progetto

```
Brain/
├── Brain.xcodeproj
├── Brain/                    solo app
│   ├── App/                  avvio, database aperto, risposte alle notifiche
│   ├── Features/
│   │   ├── Today/            Oggi, riepilogo, Annulla, valore numerico, riordino, archiviati
│   │   ├── GoalDetail/       dettaglio, calendario, giorno (stato/pausa/nota), statistiche
│   │   ├── GoalEditor/       nuovo / modifica obiettivo e tipo
│   │   └── Settings/         promemoria, backup e ripristino
│   ├── Services/             notifiche locali, Apple Salute
│   ├── Preview/              dati di esempio per le anteprime di Xcode
│   └── Assets.xcassets
├── Shared/                   compilata in app e widget
│   ├── Logic/                calcoli puri (testati)
│   ├── Models/               Goal, DayEntry, scritture
│   ├── Store/                database condiviso e migrazione dalla v1
│   ├── Design/               colori, pallini, formati in italiano
│   └── Intents/              azione dei pulsanti del widget
├── BrainWidget/              widget
├── BrainTests/               test dei calcoli
├── BrainUITests/             test dell'interfaccia
└── Config/                   entitlements e Info.plist
```

## 8. Prova rapida

1. **Meno di 30 secondi:** tocca **+**, scrivi il nome, tocca **Salva**, poi **✓** sulla riga.
2. **Un tocco:** ✗ e ✓ registrano subito; un secondo tocco torna a "non registrato". In fondo compare **Annulla**.
3. **Pausa e note:** apri un obiettivo e tocca un giorno del calendario.
4. **Persistenza:** chiudi l'app dal multitasking e riaprila: pallini e numeri restano uguali.
5. **Widget:** tocca ✓ nel widget, poi apri l'app: lo stato è aggiornato.
