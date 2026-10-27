# ACT Matrix — iOS v1.1.0

Un'app iPhone/iPad **SwiftUI + UIKit**, privata, senza server né account, che salva automaticamente le matrici ACT sul dispositivo. Richiede iOS 17+. Il progetto include il workflow GitHub Actions che genera un IPA non firmato, per l'installazione tramite SideStore (come per StripStudio).

## Novità della versione 1.1

### Tipi di voce sopra la tastiera

Quando il cursore si trova su una voce, puoi assegnarle uno di questi tipi direttamente dalla barra sopra la tastiera:

- **💭 Pensiero**
- **🎇 Sensazione**
- **🏞️ Immagine**
- **🔲 Da fare** (etichetta visiva; non è ancora una checkbox spuntabile)

La voce standard ha il simbolo **•**. Se premi di nuovo il pulsante del tipo già selezionato, la voce torna a un normale punto elenco.

**Invio crea una nuova voce con la stessa icona della voce attuale**, anche quando inserisci una nuova voce in mezzo a un elenco. L'icona appartiene alla singola voce e viene salvata insieme al testo; spostare il cursore su un'altra voce aggiorna l'indicatore di selezione. Passando da un riquadro all'altro tramite la mini-matrice, si prepara un punto vuoto in fondo all'elenco, ereditando il tipo dell'ultimo punto se questo è già compilato.

### Barra della tastiera

La barra ha due file compatte. Il pulsante per mostrare tutta la matrice è centrato:

```text
                 💭   🎇   🏞️   🔲

[ Nuova ]                [ ▦ ]                 [ □ □ ]
                                              [ □ □ ]
```

- **Nuova**: crea una matrice ACT vuota.
- **Quattro emoji**: cambiano il tipo della voce selezionata.
- **Griglia (centro/destra)**: chiude l'editor/tastiera e mostra di nuovo i quattro riquadri.
- **Quattro mini-quadrati trasparenti**: cambiano immediatamente il riquadro e aprono la scrittura su un nuovo punto (o sull'ultimo vuoto).

### Scorrimento dei riquadri

Nella vista 2×2 le dimensioni dei riquadri **restano fisse**, anche dopo aver aggiunto molte voci. Puoi scorrere **verticalmente all'interno di ciascun riquadro** per leggere le voci che non entrano. Tocca un riquadro per ingrandirlo, aprire la tastiera e scrivere su una voce nuova; i bordi degli altri riquadri restano parzialmente visibili. Anche l'editor ingrandito scorre quando l'elenco diventa lungo.

### Home organizzata per data

Il menu **☰** in alto a sinistra apre la home a tutto schermo. Le matrici sono disposte come un albero espandibile/comprimibile:

```text
▾ Ottobre 2026 (7)
    ▾ Martedì 27 (3)
        Matrice del 27 ott, 17:22
        Matrice del 27 ott, 14:10
        Matrice: Riunione
    ▸ Lunedì 26 (4)
▸ Settembre 2026 (5)
```

L'ordine è dal più recente al meno recente. Mese e giorno sono calcolati dalla **data e ora di creazione originale**, non dalle successive modifiche. All'apertura la home mostra espanso il giorno più recente; tutti i mesi e giorni si possono espandere e comprimere indipendentemente. Tocca una matrice per riaprirla; fai swipe verso sinistra su una voce dell'archivio per rinominare o eliminare.

## Aggiornare da v1.0: i dati vengono mantenuti

- Il **bundle identifier non è cambiato**: `app.actmatrix.mobile`.
- Il formato dati v1.0 (`[[String]]`) viene letto automaticamente e convertito nel nuovo formato v1.1 (`[[ACTEntry]]`, con tipo di icona per voce).
- I backup JSON esportati da v1.0 **possono essere importati anche nella v1.1**.
- Installa l'IPA aggiornato **sopra la vecchia app**, senza cancellarla o disinstallarla, per conservare il contenitore dati.
- **Consigliato:** prima di aggiornare, apri Home → `⋯` → **Esporta backup JSON**. Il backup contiene i contenuti in chiaro e va custodito in un posto privato.

## Installazione tramite GitHub Actions + SideStore

1. Carica **il contenuto** della cartella `ACTMatrix-iOS`, non la cartella contenitore, nella radice del tuo repository GitHub esistente. Sostituisci i file `.swift`, `ACTMatrix.xcodeproj/project.pbxproj`, `README.md` e gli altri presenti; mantieni la cartella nascosta `.github/workflows/build-ios.yml`.
2. GitHub → repository → **Actions** → **Build ACT Matrix iOS (unsigned IPA)** → **Run workflow**.
3. Quando il workflow termina con successo, scarica l'artefatto **ACTMatrix-unsigned-IPA**, estrailo e trova `ACTMatrix-unsigned.ipa`.
4. Su iPhone attiva **LocalDevVPN**, apri **SideStore** → **+** → scegli l'IPA nell'app **File**.
5. Installa **come aggiornamento**, senza prima eliminare la vecchia ACT Matrix. Rinnova periodicamente le firme in SideStore.

Non è necessario Xcode sul PC Windows, ma il runner GitHub macOS compila il progetto con Xcode. Il file ZIP distribuito qui **non è un IPA**.

## Struttura del progetto

```text
ACTMatrix.xcodeproj/project.pbxproj
ACTMatrix/ACTMatrixApp.swift
ACTMatrix/MatrixStore.swift           # tipi per voce, salvataggio e migrazione v1
ACTMatrix/MatrixView.swift            # matrice 2x2, zoom e anteprima scorrevole
ACTMatrix/BulletedEditor.swift        # editor UIKit e propagazione dell'icona con Invio
ACTMatrix/MatrixKeyboardBar.swift     # comandi sopra la tastiera
ACTMatrix/ArchiveView.swift          # home ad albero mese -> giorno -> matrici
ACTMatrix/Assets.xcassets/
.github/workflows/build-ios.yml
```

## Verifiche e limiti

- Verificata localmente la sintassi Swift di tutti i file.
- Testata con Swift la migrazione di un backup di v1.0, la decodifica/codifica del formato v1.1 e l'interpretazione delle quattro emoji.
- Non è possibile eseguire qui l'interfaccia iOS o `xcodebuild`: **il primo build reale si verifica nel workflow GitHub**, ed eventuali errori del compiler iOS devono essere corretti usando il suo log.
- L'icona 🔲 indica un'azione da fare ma non gestisce ancora lo stato completato; per le altre emoji si tratta di classificazioni visive, non riconoscimento automatico del contenuto.


## Correzione 1.1.1 (27 ottobre 2026)

Corretto l'errore di compilazione Swift in `ACTMatrix/MatrixStore.swift` nell'inizializzatore di `MatrixStore` (lettura di `matrices` prima che `activeID` sia inizializzato). Non vengono modificati il bundle identifier, il formato dei salvataggi o il workflow GitHub Actions.

Se il repository contiene gia la versione 1.1.0, e sufficiente sostituire il solo file `ACTMatrix/MatrixStore.swift`, poi rieseguire il workflow dalla scheda **Actions**.
