# ACT Matrix iOS — v1.5.0

App iPhone offline (SwiftUI + UIKit, iOS 17+). Resta invariato il bundle ID `app.actmatrix.mobile` e il percorso locale dei dati: aggiornare tramite SideStore **senza disinstallare** l'app. Prima dell'aggiornamento, esportare un backup JSON da Home → menu ⋯.

## Novità v1.5.0

1. **🎗️ Ricordo e 🔈 Suono:** nuovi tipi di voce nella barra sopra la tastiera, accanto a 💭 🎇 🏞️ 🔲; anche le sottovoci possono usare entrambe le icone. Premendo di nuovo il tipo scelto si ritorna al punto elenco normale.
2. **Me Noticing:** il `−` al centro della matrice ora ha una propria area di tocco, separata dal pulsante di incremento. Ritornare dal riquadro ingrandito alla vista 2×2, con il pulsante in alto o sopra la tastiera, incrementa automaticamente Me Noticing di **1** (non quando si apre Home o una nuova matrice).
3. **Virgolette automatiche per i pensieri:** Home ☰ → ⚙️ Impostazioni → *Racchiudi sempre i pensieri tra “virgolette”*. Attiva la presentazione con virgolette tipografiche in anteprima, nello zoom e nel filtro pensieri. La preferenza è locale e **non altera il testo originale nei salvataggi**.
4. **Backspace in una sottovoce vuota:** se premi Cancella all'inizio di una sottovoce vuota, il rientro diminuisce di un livello per volta; solo quando raggiunge il livello zero si può unire alla riga precedente.
5. **Livello zero quando riapri un riquadro:** dalla vista totale, una nuova voce viene creata al livello principale (non eredita il rientro dell'ultima sottovoce).
6. **To-do globali:** Home ☰ → *Tutti i to-do*. Include i to-do delle **diverse matrici**, indicando matrice di origine e data; toccare il testo apre i rispettivi appunti, senza confondere le matrici.
7. **Drag con anteprima nella lista to-do:** mentre trascini, le altre voci si spostano in modo animato per far spazio. Il nuovo ordine viene salvato solo nella lista to-do della matrice corrente: la matrice originale rimane invariata.
8. **Swipe nella vista ingrandita:** swipe **verso destra** per visualizzare solo le 🏞️ immagini, swipe **verso sinistra** per visualizzare solo i 💭 pensieri. Le sottoramificazioni sono nascoste per impostazione predefinita e si possono espandere toccando il relativo chevron. Usa la matita nella barra superiore per ritornare alla scrittura, oppure l'icona 2×2 per tornare alla matrice completa.

## Aggiornamento dall'iPhone, senza cambiare il workflow

Usando **ACTMatrix-update-v1.5.0-5-Swift.zip**, estrai lo ZIP nell'app File e sostituisci **cinque file** nella cartella `ACTMatrix/` del repository GitHub:

- `MatrixStore.swift`
- `MatrixView.swift`
- `BulletedEditor.swift`
- `MatrixKeyboardBar.swift`
- `ArchiveView.swift`

Se desideri che iOS mostri la nuova versione nelle informazioni dell'app, sostituisci facoltativamente il file `ACTMatrix.xcodeproj/project.pbxproj` con quello del progetto completo (**v1.5.0, build 8**). Non è necessario aggiornare il workflow `.github/workflows/build-ios.yml`, che è identico a quello già funzionante.

Dopo aver fatto *Commit changes*, apri **Actions → Build ACT Matrix iOS (unsigned IPA) → Run workflow**. Scarica l'artefatto `ACTMatrix-unsigned-IPA`, estrai `.ipa` e installalo tramite SideStore senza cancellare l'app esistente.

## Compatibilità e controlli

Il modello importa i backup dalla versione 1 alla 6. La v6 aggiunge solamente nuovi valori per `ACTEntryKind` (ricordo/suono); gli ID delle voci, contatori, note, rientri, ordine to-do e Me Noticing esistenti vengono preservati. Le virgolette sono una preferenza in UserDefaults e non cambiano il file JSON.

**Controlli locali eseguiti:** analisi sintattica dei file Swift con Swift 6 su Linux; test di decodifica di salvataggi precedenti, serializzazione e conservazione dei contatori; verifica dei file e degli ZIP. **Questi controlli non sostituiscono una build Xcode/iPhone reale**: la verifica finale avviene su GitHub Actions e poi sul dispositivo, soprattutto per swipe, riordino dinamico e tastiera.
