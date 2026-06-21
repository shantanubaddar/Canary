# Canary Desktop

Canary Desktop is the current Flutter Linux app for Canary, a local-first music library and player for user-owned audio files.

## Features

- Import audio files and folders.
- Confirm and correct metadata before saving to the library.
- Search songs, albums, artists, and genres.
- Browse recently added songs, albums, artists, playlists, and full library.
- Manage albums with custom artwork, metadata artwork search, add-song flow, and delete confirmation.
- Play local files with a floating vertical player.
- Persist the local library and cached artwork on disk.

## Run

```sh
/home/shantanu/flutter/bin/flutter run -d linux
```

## Verify

```sh
/home/shantanu/flutter/bin/flutter analyze
/home/shantanu/flutter/bin/flutter test
```

## Module Layout

- `lib/main.dart` - app startup and top-level shell.
- `lib/features/library/` - library controller and library views.
- `lib/features/album/` - album screen and album management.
- `lib/features/import/` - file import and metadata correction dialogs.
- `lib/features/player/` - playback state and player UI.
- `lib/features/metadata/` - metadata and image lookup.
- `lib/features/dashboard/` - dashboard routing and search results.
- `lib/ui/` - shared UI components and theme.

## Legal Notice

Canary Desktop does not provide music or bypass DRM. It is intended for local audio files the user owns or is authorized to use. Metadata and artwork lookup is provided for user-confirmed personal library organization.

See [`../LEGAL_NOTICE.md`](../LEGAL_NOTICE.md).
