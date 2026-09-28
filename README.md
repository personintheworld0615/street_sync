# street_sync

A Flutter app for community reporting and map-based issue tracking.

## API key and secret placement

Keep all real Google API keys and map IDs out of Git. Use local config files and platform-specific env variables instead.

### Web (Vercel)

Set the following environment variables in Vercel:

- `MAPS_API_KEY`
- `MAP_ID` (optional if you are not using a custom map ID yet)

Then run the build step before `flutter build web`:

```bash
MAPS_API_KEY="$MAPS_API_KEY" MAP_ID="$MAP_ID" node ./scripts/inject-maps-key.js
flutter build web
```

Do not commit a real web key into `web/index.html`.

### Android

Create a local file at `android/local.properties` and add:

```properties
MAPS_API_KEY=your_android_maps_key_here
MAP_ID=your_android_map_id_here
```

This file is already ignored in Git.

### iOS

This project already includes an example config file at `ios/Runner/Secrets.xcconfig.example`.

Create your real local file like this:

```bash
cp ios/Runner/Secrets.xcconfig.example ios/Runner/Secrets.xcconfig
```

Then set values like:

```properties
GOOGLE_MAPS_API_KEY=your_ios_maps_key_here
MAP_ID=your_ios_map_id_here
```

Do not commit the real `ios/Runner/Secrets.xcconfig` file.

### Security notes

- Keep separate keys for web, Android, and iOS.
- Restrict each key to the correct platform and minimal API list.
- If a key was ever committed or pasted into chat, rotate it in Google Cloud Console.
- Treat a web key as public, and protect it with referrer restrictions and a narrow API allowlist.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
