# client

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Admin screens (ADM-15–ADM-18)

Start services from the repository root:

```bat
docker compose -f compose.dev.yml up -d --build
```

Then run the client in a second terminal:

```bat
cd client
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080
```

After administrator sign-in, open **Thống kê** for access/recognition analytics
and **Cấu hình hệ thống** for operational/recognition settings. Click a weekday
to edit opening hours. Values remain drafts until **Lưu cấu hình** is selected.
Analytics use API data; screenshot values are test fixtures only.

ADM-18 requires either all four calibration fields or all four blank. Saving
blank fields sends `resetFaceConfiguration: true` to the versioned configuration
PATCH API, clearing calibration without changing operational settings. This flag
cannot accompany non-null calibration values. A version conflict preserves the
draft and offers **Tải bản mới**.

Checks: `flutter test test/features/admin` and
`flutter analyze lib/features/admin test/features/admin`.
