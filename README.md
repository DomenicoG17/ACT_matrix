# ACT Matrix — app iOS privata e offline

Progetto **SwiftUI + UIKit**, senza dipendenze esterne e senza server. Compatibile con iOS 17 o successivo. È pensato per essere compilato su GitHub Actions da Windows (o iPhone) e installato tramite SideStore, con lo stesso percorso utilizzato per StripStudio.

## Funzioni della versione 1.0

- Nuova matrice con quattro riquadri vuoti (solo titoli di orientamento ACT).
- Tocca un riquadro: esso si espande fino a coprire l'89% circa di larghezza/altezza, lasciando visibili strisce dei riquadri accanto.
- La tastiera si apre automaticamente con il cursore su un elenco puntato.
- Il tasto **Invio** crea un nuovo punto.
- **Sopra la tastiera**: quattro piccoli pulsanti trasparenti in griglia 2×2, corrispondenti ai quattro riquadri. Toccarne uno cambia sezione e porta il cursore all'ultimo punto vuoto (o ne aggiunge uno).
- Sopra la tastiera, a sinistra, pulsante **Nuova** per creare subito una matrice vuota.
- Pulsante **griglia** in alto per tornare alla vista dei quattro riquadri.
- **Archivio** in alto a sinistra: tutte le matrici, ordinate per data di creazione, con titolo, data/ora, conteggio dei punti, apertura, rinomina ed eliminazione.
- Salvataggio automatico dopo ogni modifica, anche senza Internet.
- Esportazione e importazione di backup JSON dall'archivio (l'importazione aggiunge matrici mancanti, non cancella quelle esistenti).

### Disposizione ACT utilizzata

```text
┌───────────────────────────┬───────────────────────────┐
│ Azioni di allontanamento  │ Azioni di avvicinamento   │
│ (Away moves)              │ (Toward moves)            │
├───────────────────────────┼───────────────────────────┤
│ Pensieri ed emozioni      │ Persone e valori         │
│ (esperienze interiori)    │ (who / what matters)      │
└───────────────────────────┴───────────────────────────┘
```

**Nota**: i titoli sono indicazioni di orientamento, non contenuti precompilati. I tuoi elenchi cominciano vuoti. La distribuzione segue la convenzione con comportamenti osservabili in alto e vissuti interiori in basso.

## Installazione con GitHub e SideStore

1. Crea un repository GitHub, ad esempio `ACTMatrix`. Carica **il contenuto** di questa cartella nella radice del repository (non la cartella contenitore `ACTMatrix-iOS`). È fondamentale includere la cartella nascosta `.github/workflows`.
2. Vai su GitHub → repository → **Actions** → **Build ACT Matrix iOS (unsigned IPA)** → **Run workflow**.
3. Quando il workflow è verde, aprilo e scarica l'artefatto **ACTMatrix-unsigned-IPA**. GitHub fornisce un file `.zip` che contiene **ACTMatrix-unsigned.ipa**: estrai lo ZIP, non rinominare lo ZIP in IPA.
4. Su iPhone, apri SideStore con LocalDevVPN attiva. Usa il pulsante **+** nella sezione delle app per selezionare `ACTMatrix-unsigned.ipa` dall'app File. SideStore firma l'IPA tramite il tuo account Apple e installa l'app.
5. Per aggiornare, sostituisci i file del repository, esegui nuovamente il workflow e installa il nuovo IPA **sopra quello già presente**, senza disinstallare l'app: questo normalmente conserva i dati. Mantieni invariato il bundle ID (attualmente `app.actmatrix.mobile`).

### Note importanti

- **Questo archivio ZIP non è già un IPA**. L'IPA viene creato sul runner macOS di GitHub; qui non è possibile compilare un'app iOS per dispositivo o provare l'installazione reale.
- Il bundle ID di ACT Matrix è diverso da quello di StripStudio (`app.stripstudio.mobile`): le app sono indipendenti.
- La firma SideStore va rinnovata regolarmente (in genere ogni 7 giorni con account Apple gratuito).
- Il limite SideStore può essere **3 app attive, SideStore inclusa**, con account gratuito.
- I dati sono nel contenitore locale dell'app, non nei file del repository. Eliminare l'app può cancellarli. **Esporta un backup dall'archivio** prima di disinstallare o cambiare metodo di installazione.
- Un backup JSON contiene i tuoi contenuti in chiaro. Conservalo in un luogo privato.

## Struttura

```text
ACTMatrix.xcodeproj/project.pbxproj
ACTMatrix/ACTMatrixApp.swift
ACTMatrix/MatrixStore.swift
ACTMatrix/MatrixView.swift
ACTMatrix/BulletedEditor.swift
ACTMatrix/MatrixKeyboardBar.swift
ACTMatrix/ArchiveView.swift
ACTMatrix/Assets.xcassets/AppIcon.appiconset/
.github/workflows/build-ios.yml
```

### Modifiche future

Per personalizzare etichette, colori e navigazione: `MatrixView.swift` e `MatrixKeyboardBar.swift`. Per formato di salvataggio: `MatrixStore.swift`. Per comportamento dell'elenco puntato: `BulletedEditor.swift`.
