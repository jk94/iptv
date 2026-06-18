# IPTV Player

Eine moderne IPTV-Player-App für **Android und iOS**, gebaut mit Flutter (Material 3, Dark Mode).

## Funktionen

- **Mehrere Playlists** hinterlegen:
  - **M3U/M3U8** per URL (mit `group-title` als Kategorie und `tvg-logo`)
  - **Xtream Codes** per Server, Benutzername und Passwort
- **Navigation:** Playlist → Kategorie → Stream → Player
- **Startseite** mit „Zuletzt gesehen" und Playlist-Übersicht
- **Einstellungen** zum Verwalten, **Bearbeiten** und Löschen der Playlists
- **Channel-Cache:** Geladene Streams werden lokal gespeichert und beim
  Neustart aus dem Cache geladen; ein Button an jeder Playlist erzwingt das
  Neuladen (Startseite und Einstellungen)
- **Video-Player** im Vollbild (Querformat) mit automatisch ausblendenden Bedienelementen, LIVE-Badge und Bildschirm-Wachhalten (Wakelock)
- **Sender wechseln** direkt im Player über Vor-/Zurück-Buttons (nächster Stream
  derselben Kategorie)
- **Picture-in-Picture (Android):** Die Wiedergabe läuft in einem schwebenden
  Fenster weiter, wenn die App in den Hintergrund verschoben wird
- Suche in Kategorien und Streams

## Projektstruktur

```
lib/
├── main.dart                  # App-Einstieg, Bottom-Navigation (Start / Einstellungen)
├── theme.dart                 # Dunkles Material-3-Theme
├── models/models.dart         # Playlist, Channel, RecentEntry
├── services/
│   ├── m3u_parser.dart        # M3U/M3U8-Parser
│   └── playlist_loader.dart   # Lädt Streams aus M3U-URL oder Xtream-API
├── state/app_state.dart       # Zentraler App-State (provider + shared_preferences)
├── screens/
│   ├── home_screen.dart       # Startseite
│   ├── settings_screen.dart   # Einstellungen / Playlist-Verwaltung
│   ├── categories_screen.dart # Kategorie-Auswahl
│   ├── channels_screen.dart   # Stream-Auswahl in einer Kategorie
│   └── player_screen.dart     # Vollbild-Video-Player
└── widgets/channel_logo.dart  # Senderlogo mit Fallback
```

## Entwicklung

```bash
flutter pub get
flutter run            # App starten (Gerät/Emulator nötig)
flutter test           # Unit-Tests (M3U-Parser)
flutter analyze        # Statische Analyse
```

### Builds

```bash
flutter build apk      # Android
flutter build ios      # iOS (benötigt macOS/Xcode)
```

## Releases

Ein Push eines Tags im Format `v1.1.1` startet die Release-Pipeline
(`.github/workflows/release.yml`):

1. `flutter analyze` und `flutter test`
2. Android-Build: universelle APK, APKs pro ABI (arm64-v8a, armeabi-v7a) und App Bundle (`.aab`)
3. iOS-Build: unsignierte `.ipa` (muss vor der Installation nachsigniert werden, z. B. mit AltStore/Sideloadly oder Xcode)
4. GitHub-Release mit allen Paketen und automatischen Release-Notes

```bash
git tag v1.1.1
git push origin v1.1.1
```

Der Versionsname der App wird dabei aus dem Tag übernommen (`v1.1.1` → `1.1.1`).

## Hinweise

- Viele IPTV-Streams laufen über `http://` — Cleartext-Traffic (Android) und
  `NSAllowsArbitraryLoads` (iOS) sind dafür bereits konfiguriert.
- Die App liefert keine Inhalte mit; es werden ausschließlich vom Nutzer
  hinterlegte Playlists abgespielt.
- **Picture-in-Picture** ist über das Plugin `simple_pip_mode` umgesetzt und
  steht nur unter **Android** zur Verfügung (automatisches Wechseln in den
  PiP-Modus ab Android 12, manueller Button ab Android 8). Unter iOS bietet
  `video_player` kein PiP; dort bleibt der Vor-/Zurück- und Caching-Funktionsumfang
  unverändert verfügbar.
