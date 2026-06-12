# IPTV Player

Eine moderne IPTV-Player-App für **Android und iOS**, gebaut mit Flutter (Material 3, Dark Mode).

## Funktionen

- **Mehrere Playlists** hinterlegen:
  - **M3U/M3U8** per URL (mit `group-title` als Kategorie und `tvg-logo`)
  - **Xtream Codes** per Server, Benutzername und Passwort
- **Navigation:** Playlist → Kategorie → Stream → Player
- **Startseite** mit „Zuletzt gesehen" und Playlist-Übersicht
- **Einstellungen** zum Verwalten der Playlists und Löschen des Verlaufs
- **Video-Player** im Vollbild (Querformat) mit automatisch ausblendenden Bedienelementen, LIVE-Badge und Bildschirm-Wachhalten (Wakelock)
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

## Hinweise

- Viele IPTV-Streams laufen über `http://` — Cleartext-Traffic (Android) und
  `NSAllowsArbitraryLoads` (iOS) sind dafür bereits konfiguriert.
- Die App liefert keine Inhalte mit; es werden ausschließlich vom Nutzer
  hinterlegte Playlists abgespielt.
