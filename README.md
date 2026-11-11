# Space Arcade

Raccolta di minigiochi a tema spazio per tablet Android/iOS. Motore: **Godot 4.3+** (GDScript), orientamento landscape.

## Avvio
1. Installa Godot 4.3 o piÃ¹ recente (versione standard, non .NET): https://godotengine.org/download
2. Godot â†’ Import â†’ seleziona `project.godot` â†’ Run (F5).

## Stato
| Gioco | Stato |
|---|---|
| Hub | pronto |
| Scacchi (vs IA, 3 livelli) | pronto (regole complete; niente patta per ripetizione/50 mosse) |
| Cruciverba (generato a ogni partita, 3 livelli, tastiera su schermo) | pronto |
| Mostri cosmici (isola con mostri che cantano e producono monete, negozio, potenziamenti, battaglie a turni) | pronto, da provare |
| Parkour 3D (corsa infinita, 3 corsie: cambia corsia, salta, scivola, monete) | pronto, da provare |
| Indovina il mostro (senti il canto di un mostro cosmico, poi scegli il nome; 3 livelli, 10 domande) | pronto, da provare |

## Struttura
- `scripts/game.gd` â€“ autoload, cambio schermata e tasto Indietro Android
- `scripts/hub.gd` â€“ menu principale; per aggiungere un gioco: voce in `GAMES` + schermata in `Game.SCREENS`
- `scripts/chess_engine.gd` â€“ regole e IA; `chess_board.gd` â€“ disegno e tocco; `chess_screen.gd` â€“ UI

## Export su tablet
- **Android**: Editor â†’ Install Android Build Template, serve Android SDK + JDK 17; poi Project â†’ Export â†’ Android.
- **iOS**: l'export richiede un Mac con Xcode e un account Apple Developer.

### iPad senza Mac: versione web (consigliata per i test)
Il progetto si pubblica come sito su GitHub Pages; sull'iPad si apre in Safari â†’ Condividi â†’ "Aggiungi alla schermata Home" e parte a schermo intero con l'icona.
1. Crea un account GitHub (gratis) e un repository pubblico; carica tutto il contenuto di questa cartella (compresa `.github`).
2. Repository â†’ Settings â†’ Pages â†’ Source: **GitHub Actions**.
3. Ogni push su `main` esegue `.github/workflows/web.yml`, che esporta il gioco e lo pubblica. L'indirizzo compare in Actions â†’ ultima esecuzione.
Note: la versione web usa il renderer Compatibility; i progressi dei mostri restano nel browser dell'iPad.

### iPad in test (TestFlight, serve un Mac)
L'icona Ã¨ `icon.png` (1024x1024, senza trasparenza, giÃ  impostata in `project.godot`).
1. Account Apple Developer (99 $/anno) e, su App Store Connect, crea una nuova app con un Bundle ID (es. `com.tuonome.spacearcade`).
2. Su un Mac, apri il progetto in Godot 4.7 e installa i modelli di esportazione (Editor â†’ Manage Export Templates).
3. Project â†’ Export â†’ Addâ€¦ â†’ iOS. Imposta: Bundle Identifier, App Store Team ID, Icon 1024 = `res://icon.png`, Targeted Device Family = iPad (o iPhone + iPad).
4. Esporta: Godot crea un progetto Xcode. Aprilo, scegli il Team in Signing, poi Product â†’ Archive â†’ Distribute App â†’ App Store Connect.
5. In App Store Connect â†’ TestFlight aggiungi te stesso come tester; sull'iPad installa l'app TestFlight e accetta l'invito.
Per provare solo sul tuo iPad senza TestFlight: collega l'iPad al Mac e premi Run da Xcode.

