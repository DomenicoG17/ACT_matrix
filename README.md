# ACT Matrix — iOS v1.3.1

App locale, offline, realizzata in SwiftUI/UIKit. Mantiene lo stesso `PRODUCT_BUNDLE_IDENTIFIER` (`app.actmatrix.mobile`) e il workflow di GitHub Actions delle versioni precedenti.

## Correzioni nella versione 1.3.1

- Nella **vista completa della matrice**, il tasto `+` di ciascuna voce è più piccolo, sottile e grigio chiaro. Anche il tasto `−` è grigio chiaro; **solo il numero delle ricorrenze resta rosso**.
- Nei riquadri **già compilati**, toccando la zona libera sotto le voci (o i margini vuoti) si entra nello zoom con tastiera, proprio come avviene nei riquadri vuoti. Lo scorrimento rimane disponibile e i pulsanti dei contatori e i link to-do mantengono la loro funzione.

## Funzioni della versione 1.3.0

- **Sottovoci:** in modifica premi **↳** sulla barra sopra la tastiera per aumentare il rientro (fino a quattro livelli); premi **⇤** per diminuire il rientro. Le sottovoci mostrano il simbolo **↳** al posto del normale punto elenco. La categoria della voce (pensiero, sensazione, immagine o to-do) resta memorizzata anche quando il suo simbolo non viene mostrato.
- **To-do con appunti:** premendo **🔲** sulla barra della tastiera la voce diventa un to-do. Il testo appare **blu e sottolineato**: toccandolo apri una **pagina bianca di appunti**, salvata automaticamente e associata a quella sola voce. La barra dei comandi resta disponibile anche negli appunti (nuova matrice, griglia, navigazione, tipi e rientro).
- **Vista dedicata ai to-do:** dalla panoramica 2×2 fai **swipe dal bordo destro verso sinistra**, oppure tocca l'icona checklist nella barra superiore. La pagina mostra tutti i to-do della matrice corrente. Per tornare alla matrice, tocca l'icona griglia o scorri dal bordo sinistro verso destra.
- **Ordine indipendente dei to-do:** tieni premuta una voce e **trascinala** nella lista to-do. L'ordine della matrice originale non cambia.
- **Riordino nella matrice:** quando visualizzi i quattro riquadri, tieni premuta una voce e trascinala all'interno **dello stesso riquadro**. Si sposta nella matrice originale senza modificare i contatori o gli appunti. Il suo eventuale livello di rientro resta quello selezionato.
- Le funzioni esistenti restano disponibili: zoom, editor con quattro pulsanti di navigazione, contatori rossi +/−, archivio ad albero mese → giorno, backup JSON.

## Salvataggi / aggiornamento

Le nuove proprietà (`id`, `indentLevel`, `note` e `todoOrder`) vengono lette in modo retrocompatibile: se mancano nei vecchi salvataggi, vengono create o usano valori predefiniti. Tutti i contatori esistenti vengono mantenuti. Il backup ora usa la versione 4; si possono importare backup delle versioni 1–4. Consigliato esportare comunque un backup PRIMA di aggiornare.

## Compilazione GitHub da iPhone

1. Nel repository `DomenicoG17/ACT_matrix`, sostituisci questi quattro file dentro la cartella `ACTMatrix/`: `MatrixStore.swift`, `BulletedEditor.swift`, `MatrixKeyboardBar.swift` e `MatrixView.swift`. **Se parti già dalla v1.3.0, devi sostituire solo `ACTMatrix/MatrixView.swift`.**
2. Facoltativo ma consigliato: sostituisci `ACTMatrix.xcodeproj/project.pbxproj` per mostrare v1.3.1 (build 5).
3. **Non occorre cambiare `.github/workflows/build-ios.yml`.** Vai in GitHub **Actions → Build ACT Matrix iOS (unsigned IPA) → Run workflow**.
4. Scarica l'artefatto **ACTMatrix-unsigned-IPA** → estrai l'IPA → installa con **SideStore**, senza cancellare l'app esistente (stesso bundle ID).

Non hai bisogno di aggiungere nuovi file al progetto Xcode: tutte le nuove schermate sono contenute in `MatrixView.swift`.

## Verifiche

Il progetto è stato verificato con il parser Swift, controllo delle modifiche e test di serializzazione/migrazione in ambiente Swift/Linux. La compilazione completa per iPhone richiede il runner macOS di GitHub Actions; non è stata effettuata localmente.
