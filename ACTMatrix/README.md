# ACT Matrix — iOS v1.4.0

Applicazione iOS offline (SwiftUI + UIKit, iOS 17+), dati salvati esclusivamente sul dispositivo. Rimangono **invariati** l'identificativo `app.actmatrix.mobile`, il percorso del salvataggio e il workflow `.github/workflows/build-ios.yml`, quindi puoi installare l'aggiornamento con SideStore senza rimuovere la versione precedente. **Esporta prima un backup JSON** per sicurezza.

## Novità v1.4.0

1. **Me Noticing:** pulsante al centro dell'incrocio dei quattro riquadri nella vista completa. Toccalo per registrare un momento di consapevolezza; il numero rosso è indipendente per ogni matrice e si salva automaticamente. Il piccolo `−` (quando il numero è maggiore di 0) permette di correggerlo.
2. **Cancellazione alla fine di una voce:** premendo Backspace sul simbolo di una voce successiva o sul ritorno a capo, l'editor fonde correttamente le righe, eliminando il simbolo duplicato. Una voce vuota alla fine si elimina senza lasciare icone ripetute.
3. **Ramificazioni con icona:** oltre alla freccia a L `↳`, una sottovoce mostra ora anche l'icona che scegli con i pulsanti della barra sopra la tastiera (ad esempio `↳ 💭 Pensiero`). L'icona resta modificabile anche dopo aver aumentato il rientro.
4. **Pulsanti dei contatori più discreti:** nell'editor ingrandito, `+` e `−` sono piccoli e grigi; soltanto il numero delle ricorrenze è rosso, come nella panoramica.
5. **Testo di invito facoltativo:** la scritta "Tocca per scrivere…" è **nascosta per impostazione predefinita**, ma puoi riattivarla in **☰ Home → ⚙︎ Impostazioni → Mostra «Tocca per scrivere»**. Il tocco per modificare funziona anche con la scritta nascosta.
6. **Scorrimento fra matrici:** nella panoramica completa, fai swipe **verso l'alto** per passare a una matrice più vecchia e **verso il basso** per una più recente. Per evitare conflitti con lo scorrimento delle voci dentro i riquadri, **inizia lo swipe dalla zona centrale oppure da un bordo laterale**. Non c'è passaggio automatico dall'ultima alla prima. Il titolo ora mostra il numero della matrice rispetto al totale.
7. **Testo delle sottovoci su più righe:** se una voce rientrata va a capo automaticamente, le righe successive iniziano allineate al testo della sottovoce, non al margine del riquadro (rientro sporgente di paragrafo).

## Aggiornamento da GitHub usando solo l'iPhone

### Aggiornamento rapido dalla v1.3.1

- Estrai `ACTMatrix-update-v1.4.0-4-Swift-files.zip` nell'app File.
- Carica e sostituisci i quattro file `ArchiveView.swift`, `BulletedEditor.swift`, `MatrixStore.swift` e `MatrixView.swift` nella cartella **`ACTMatrix/`** del repository `DomenicoG17/ACT_matrix`.
- Facoltativo: sostituisci `ACTMatrix.xcodeproj/project.pbxproj` con quello della versione completa per aggiornare il numero versione/build a **1.4.0 (6)**.
- Da GitHub: **Actions → Build ACT Matrix iOS (unsigned IPA) → Run workflow**. Scarica l'artefatto IPA e installalo in SideStore come aggiornamento dell'app esistente.

### Installazione con il progetto completo

Estrai `ACTMatrix-iOS-v1.4.0.zip`; caricane il contenuto nella **radice** del repository conservando le cartelle `ACTMatrix`, `ACTMatrix.xcodeproj`, `.github/workflows`. La cartella `.github` è nascosta su alcuni dispositivi; se il workflow esiste già sul repository non è necessario ricaricarla.

## Dati e compatibilità

- `ACTMatrix.meNoticingCount` è una nuova proprietà opzionale in decodifica. Per tutti i salvataggi precedenti il valore è 0.
- I contatori delle singole voci, gli ID persistenti, i to-do, gli appunti, i rientri e l'ordine personalizzato non sono azzerati.
- Nuovo formato backup **v5**, con importazione retrocompatibile delle versioni 1–5.
- L'impostazione della scritta "Tocca per scrivere…" è salvata in `UserDefaults`, separatamente dai dati delle matrici.
- Nessuna nuova dipendenza, nessuna modifica al workflow e nessun servizio online necessario per usare l'app.

## Verifiche

Eseguiti controllo sintattico di tutti i sorgenti Swift con Swift 6.2, test con Foundation per le ramificazioni, la conversione dei vecchi dati e la serializzazione del nuovo contatore, verifica dei percorsi Xcode e degli ZIP. Questi test **non equivalgono a una compilazione iOS reale**: quest'ultima richiede Xcode tramite il workflow GitHub.
