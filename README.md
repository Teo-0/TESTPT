# Raw Camera per iPhone

Due progetti indipendenti: **Raw Camera** (SwiftUI, iOS 17+) e **Raw Camera Legacy**
(UIKit, iOS 11+, per iPhone 8). Scattano con la fotocamera posteriore
fisica 1× e salvano esclusivamente **RAW Bayer in DNG**, senza conversioni,
filtri dell’app o copia HEIC/JPEG. Funzionano offline, senza account o servizi esterni.

## Scegli e scarica la versione

Apri [`docs/index.html`](docs/index.html) nel browser: contiene la scelta tra le
due versioni e download ZIP separati, già generati in `docs/downloads/`.

| Versione | Requisiti | Progetto | Istruzioni |
| --- | --- | --- | --- |
| Legacy | iOS 11+, RAW Bayer; per iPhone 8 | `RawCameraLegacy.xcodeproj` | [Installazione Legacy](distribution/legacy.md) |
| Moderna | iOS 17+, RAW Bayer; non compatibile con iPhone 8 | `RawCamera.xcodeproj` | [Installazione moderna](distribution/modern.md) |

Gli ZIP contengono **sorgenti**, non IPA firmati. Per installare occorrono Mac,
Xcode compatibile e un Team Apple. Le app hanno Bundle Identifier distinti.
La scelta resta esplicita: nessun reindirizzamento automatico basato sul browser.

La pagina è pronta per un hosting statico. Per pubblicarla su GitHub Pages,
dopo aver caricato il repository, configura la pubblicazione dalla cartella
`/docs` del branch scelto. Non è stata pubblicata durante questo lavoro.
Un download IPA o TestFlight richiederà successivamente compilazione, firma e
distribuzione Apple; non sono presenti collegamenti a pacchetti inesistenti.

Per rigenerare i download dopo modifiche al codice:

```sh
python3 scripts/package_downloads.py
python3 scripts/package_downloads.py --check
python3 -m unittest discover -s tests -v
```

Ogni archivio contiene solo il rispettivo progetto e le istruzioni per quella
versione. Non include firme, profili, DerivedData o impostazioni personali Xcode.
I paragrafi seguenti descrivono la versione moderna; per iOS 11 usa le istruzioni Legacy.

## Cosa significa “senza post processing”

AVFoundation non offre accesso completamente privo di elaborazioni all’elettronica
del sensore. Il RAW Bayer evita lo sviluppo finale della normale foto: l’app non
applica demosaicizzazione, riduzione rumore, sharpening, tone mapping o filtri al
file. Il DNG può comunque contenere metadati e istruzioni di correzione del
produttore, applicati dal programma con cui lo si apre. Non è una garanzia di dati
elettrici del sensore intatti.

**Apple ProRAW non viene usato**, perché include elaborazione computazionale.
La disponibilità del RAW Bayer è verificata a runtime, senza assumere che ogni
iPhone lo supporti. Se manca sulla fotocamera 1×, lo scatto resta disabilitato:
non esiste un ripiego silenzioso verso formati elaborati. Questa versione non
seleziona altri obiettivi né registra video RAW.

L’anteprima video è necessariamente sviluppata da iOS e non rappresenta i dati
grezzi. Esposizione, fuoco e bilanciamento del bianco rimangono automatici;
il flash è spento. Non sono presenti controlli manuali in questa versione.

## Installazione sul telefono

1. Su un Mac con Xcode 15 o successivo, apri `RawCamera.xcodeproj`.
2. Nel target **RawCamera → Signing & Capabilities**, scegli il tuo Team Apple
   e, se necessario, cambia il Bundle Identifier.
3. Collega un iPhone, abilita la modalità sviluppatore se richiesta e selezionalo
   come destinazione. Premi Run e consenti l’accesso alla fotocamera.
4. Scatta e usa **DNG** per condividere il file originale. Tutti gli scatti sono
   in **File → Sfoglia → Su iPhone → Raw Camera → RAW**; non vengono cancellati
   automaticamente. Non è necessario concedere accesso alla libreria Foto.

Il simulatore non espone una fotocamera RAW: serve un dispositivo reale per
verificare acquisizione e compatibilità. Non sono richieste dipendenze esterne.

## Verifiche

Su macOS, dalla radice del repository:

```sh
xcodebuild -project RawCamera.xcodeproj -scheme RawCamera \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild -project RawCamera.xcodeproj -scheme RawCamera \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

La workflow GitHub Actions inclusa esegue entrambe le compilazioni quando il
progetto viene pubblicato sul repository. Non sostituisce queste prove sul telefono:

- Negare il permesso: nessuno scatto; dalle impostazioni abilitarlo e tornare
  nell’app: la sessione riparte.
- Su hardware compatibile, scattare più foto e condividere un DNG; verificare
  in un lettore RAW che il file sia un DNG con mosaico CFA/Bayer e dimensioni
  sensate. La visualizzazione può applicare correzioni proprie del lettore.
- Verificare che la copia condivisa abbia lo stesso hash SHA-256 dell’originale
  esportato tramite File: l’app condivide il file, senza svilupparlo.
- Su hardware senza RAW Bayer, verificare il messaggio di incompatibilità e
  il pulsante disabilitato.
- Mandare l’app in background e riaprirla: la fotocamera si arresta e riparte.
- Verificare il messaggio di errore in caso di spazio insufficiente.

L’ambiente cloud Linux usato per creare il progetto non include Xcode o gli SDK
Apple: la compilazione e le prove hardware non sono state eseguite qui.
