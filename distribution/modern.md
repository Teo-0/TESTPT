# Raw Camera — iOS 17+

Versione SwiftUI per iPhone con iOS 17 o successivo e fotocamera posteriore
che esponga RAW Bayer. **Non compatibile con iPhone 8**. Per iPhone 8 con iOS 11
scegli il download **Raw Camera Legacy**.

Questo ZIP contiene i sorgenti, non un’app firmata installabile da Safari.

## Installazione

1. Su Mac con Xcode 15 o successivo, estrai lo ZIP e apri `RawCamera.xcodeproj`.
2. Nel target **RawCamera → Signing & Capabilities**, scegli il tuo Team Apple
   e, se necessario, un Bundle Identifier unico.
3. Collega l’iPhone, autorizza il computer, abilita la modalità sviluppatore
   se richiesta e seleziona il dispositivo come destinazione. Premi Run.
4. Consenti l’accesso alla fotocamera e scatta. Il simulatore non espone RAW.

I file sono in **File → Su iPhone → Raw Camera → RAW**. Il pulsante **DNG**
condivide l’ultimo originale. Non serve accesso alla libreria Foto.

L’app salva soltanto RAW Bayer DNG, senza conversione JPEG/HEIC né filtri
aggiunti dall’app. Non usa ProRAW. L’anteprima resta elaborata da iOS e non è
possibile garantire l’assenza di ogni trattamento interno del sensore.
Esposizione, fuoco e bilanciamento del bianco sono automatici; flash spento.

## Verifica della compilazione

```sh
xcodebuild -project RawCamera.xcodeproj -scheme RawCamera \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

La compilazione senza firma non produce un’app installabile. Per installarla
usa Run in Xcode con il tuo Team. Su telefono verifica salvataggio e lettura
dei DNG, condivisione dell’originale, permessi e ritorno dal background.

Il codice è stato preparato in Linux: compilazione Xcode e prove hardware
restano da eseguire.
