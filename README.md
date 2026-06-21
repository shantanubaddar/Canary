# Canary

Canary is a local-first music library and player for people who keep their own music files.

The current app is focused on the desktop experience first: importing local audio, confirming metadata, organizing songs into albums and artists, editing artwork, and playing music with a compact vertical control rail. The longer-term goal is a private desktop-to-phone sync flow where the desktop library remains the source of truth and the phone mirrors selected music for offline playback.

Canary does not ship with music, album art, artist images, or a prebuilt catalog.

## Current Status

Canary is an early desktop prototype. It is not a public release yet.

Implemented so far:

- Flutter Linux desktop app.
- Local music import from files or folders.
- Metadata confirmation and manual correction before import.
- Album, artist, library, recently added, and search views.
- Album management: custom artwork, metadata artwork search, add songs, and delete album.
- Local playback with a vertical floating player.
- Local persistence for the user's library.
- Local artwork and artist image caching.

Planned next:

- Desktop-to-phone sync over local network.
- Android client using shared Flutter/Dart app logic where practical.
- Smarter duplicate detection and file relocation handling.
- Better metadata source controls and provider attribution.

## Project Layout

- `canary_desktop/` - current Flutter desktop application.
- `LEGAL_NOTICE.md` - legal and content responsibility notice.

Important desktop modules:

- `lib/features/library/` - library state and library views.
- `lib/features/album/` - album pages and album management actions.
- `lib/features/import/` - file import and metadata correction dialogs.
- `lib/features/player/` - playback state and player widgets.
- `lib/features/metadata/` - metadata and artwork lookup.
- `lib/ui/` - shared UI pieces.

## Run

```sh
cd canary_desktop
/home/shantanu/flutter/bin/flutter run -d linux
```

## Verify

```sh
cd canary_desktop
/home/shantanu/flutter/bin/flutter analyze
/home/shantanu/flutter/bin/flutter test
```
# Canary Desktop v0.1.0

First public Linux desktop prototype of Canary.

## Install

Download `canary-linux-x64-v0.1.0.tar.gz`, then:

```sh
tar -xzf canary-linux-x64-v0.1.0.tar.gz
cd bundle
./canary_desktop
```

## Legal And Content Responsibility

Canary is intended for audio files that the user owns or is authorized to use. Canary does not provide music, bypass DRM, or grant rights to copyrighted media.

Metadata and artwork lookup exists to help users organize their own libraries. Album art and artist images may be copyrighted by third parties, so Canary stores fetched artwork locally for personal library use and lets users replace or remove it.

See [LEGAL_NOTICE.md](LEGAL_NOTICE.md) for details.

## License

Canary is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
