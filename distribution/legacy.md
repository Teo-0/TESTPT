# Raw Camera Legacy — iOS 11+

Versione UIKit per iPhone 8 con iOS 11. Richiede una fotocamera posteriore che
esponga RAW Bayer; l’app verifica il formato e disabilita lo scatto se manca.
Il pacchetto contiene **sorgenti**, non un’app firmata installabile da Safari.

## Installazione

1. Usa un Mac con Xcode 14.x, che supporta il deployment target iOS 11. La
   versione di macOS deve essere compatibile con la versione di Xcode scelta.
   Le versioni recenti di Xcode non supportano necessariamente iOS 11.
2. Estrai lo ZIP e apri `RawCameraLegacy.xcodeproj`.
3. In **RawCameraLegacy → Signing & Capabilities**, scegli il tuo Team Apple.
   Se necessario, cambia `com.teo0.RawCameraLegacy` con un identificativo unico.
4. Collega l’iPhone con USB, autorizza il computer, selezionalo come destinazione
   e premi Run. Se iOS lo richiede, autorizza il profilo dello sviluppatore in
   Impostazioni → Generali → Gestione profili/dispositivo. La denominazione può variare.
5. Consenti l’accesso alla fotocamera e premi **Scatta RAW**.

La modalità sviluppatore introdotta in iOS 16 non esiste su iOS 11 e non è richiesta.
Il simulatore non verifica il funzionamento della fotocamera RAW.

## Foto e limiti

Gli originali sono in **File → Su iPhone → Raw Camera Legacy → RAW** e sono
accessibili anche tramite la condivisione file del computer. **Condividi DNG**
invia l’ultimo originale. Non servono permessi per la libreria Foto. Le foto non
vengono cancellate automaticamente.

Viene richiesta solo la rappresentazione RAW Bayer: nessuna copia JPEG, nessun
filtro aggiunto dall’app, nessun ProRAW. L’anteprima è elaborata da iOS. Apple non
consente di garantire l’assenza di qualsiasi trattamento interno del sensore;
anche i lettori DNG possono applicare correzioni in fase di visualizzazione.
Fuoco, esposizione e bilanciamento del bianco sono automatici; flash spento.

La versione moderna richiede iOS 17 e non può essere installata su iPhone 8,
nemmeno aggiornandolo alla sua ultima versione iOS supportata.

## Compilazione e verifica

Con Xcode 14 selezionato, dalla directory di questo README:

```sh
xcodebuild -project RawCameraLegacy.xcodeproj -scheme RawCameraLegacy \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Questa compilazione senza firma serve come controllo e non produce un’app
installabile. Per l’installazione usa la firma e Run in Xcode, oppure un canale
di distribuzione Apple appropriato. Non basta rinominare un file ZIP in IPA.

Sul telefono verifica: permesso negato e poi abilitato, più scatti consecutivi,
DNG Bayer leggibile da uno sviluppatore RAW, condivisione senza modifica dei byte,
ritorno dal background, hardware senza RAW e errore di spazio insufficiente.

Il codice è stato preparato in Linux: compilazione Xcode e scatto su iPhone 8
con iOS 11 restano da eseguire. Non è una build hardware già certificata.
