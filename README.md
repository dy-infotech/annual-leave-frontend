# annual_leave_frontend

Annual leave management app for dy-infotech employees.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

test

## API configuration

Debug builds use the local API (`localhost:8080`, or `10.0.2.2:8080` on the
Android emulator). Profile and release builds require an HTTPS endpoint:

```sh
flutter build appbundle \
  --dart-define=API_BASE_URL=https://api.example.com
```

`API_BASE_URL` is public build configuration. Do not place API keys or other
secrets in it.

## Android release signing

Release builds are never signed with the Android debug key. Copy
`android/key.properties.example` to `android/key.properties`, replace the
placeholder values, and keep the keystore outside version control before
building a signed release.