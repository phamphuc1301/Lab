# Money Manager (Flutter)

The Flutter version of [money-manager](../money-manager/) (the SwiftUI iOS app). It has the same
features, and you can build and test it on Windows.

- **Capture receipts and invoices** from the camera (Android/iOS) or an image file (all platforms),
  or **paste receipt text**.
- **On-device text recognition (OCR)**, with no server or API key:
  - Android / iOS: Google ML Kit
  - Windows: the OCR engine built into Windows (`Windows.Media.Ocr`)
- **Receipt parser** that finds the total, date, merchant and category. It works with English and
  Vietnamese receipts (`TOTAL`, `Tổng cộng`, `Thanh toán`, `125.000đ`, `1,234.56`, …).
- **History** with search, filters, edit, and swipe-to-delete.
- **Overview** for each month: totals, spending by category, and a daily spending chart with a
  line showing your daily budget.
- **Budgets** with warnings. Each budget can be **exceeded**, at its **warning** level (80% by default),
  or **spending fast** (on pace to go over by month end). You get an in-app banner, plus a system
  notification the first time each level is reached in a month.
- **Local storage** in SQLite (sqflite). Receipt images are copied into the app's data folder.
  You can export everything to CSV.
- **English and Vietnamese (Tiếng Việt)**. By default the app follows the device language; you can
  change it in Settings → Language. Dates and money follow the language (`53.000 ₫` in Vietnamese).
  To add a language, add `lib/l10n/app_<code>.arb` and add the code to `supportedLanguages` in
  `lib/l10n/l10n.dart`.

| Platform | Camera | Image import | OCR | Notifications |
|---|---|---|---|---|
| Windows desktop | – | ✓ (file picker) | ✓ Windows OCR | ✓ |
| Android (emulator or phone) | ✓ | ✓ | ✓ ML Kit | ✓ |
| iOS (iPhone) | ✓ | ✓ | ✓ ML Kit | ✓ (built on GitHub; see below) |

## One-time setup on Windows

1. **Flutter SDK.** It's installed at `C:\Users\PC\flutter`. Add it to your PATH (in PowerShell):
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Users\PC\flutter\bin", "User")
   ```
   Open a new terminal, then run `flutter doctor`.
2. **Developer Mode.** Plugins need it for symlinks. Run `start ms-settings:developers` and turn
   **Developer Mode** on.
3. **Install at least one target:**
   - **Windows desktop app.** Install [Visual Studio 2022 Community](https://visualstudio.microsoft.com/downloads/)
     (the free edition) and tick the **Desktop development with C++** workload. The Visual Studio 2019
     Build Tools already on this PC are incomplete, so `flutter doctor` flags them.
   - **Android.** Install [Android Studio](https://developer.android.com/studio). On first launch let it
     install the SDK. Then run `flutter doctor --android-licenses`, and create an emulator in
     **Device Manager** (e.g. Pixel 8, a recent API level). You can also plug in an Android phone with
     USB debugging turned on.
4. *(Optional)* **Vietnamese OCR on Windows.** Go to Settings → Time & language → Language & region →
   Add a language → **Tiếng Việt**. Or, in an admin PowerShell:
   `Add-WindowsCapability -Online -Name "Language.OCR~~~vi-VN~0.0.1.0"`.
   Without it, Windows OCR still reads English and numbers.

## Run

```powershell
cd money-manager-flutter
flutter pub get
flutter run -d windows        # Windows desktop app
flutter run -d emulator-5554  # Android emulator (see `flutter devices` for the id)
```

To try receipt scanning on Windows, click **Add → Import receipt image** and pick a photo or a
screenshot of a receipt. `test/fixtures/receipt_en.png` is a sample you can use. You can also choose
**Paste receipt text** to test the parser without an image.

To use the camera in the Android emulator, open the emulator's **Extended controls → Camera** and set
the back camera to *Webcam0*. Then you can hold a real receipt up to your PC's webcam.

## Tests

```powershell
flutter test      # parser, budget maths, SQLite storage, and real Windows OCR on a sample image
flutter analyze
```

## Build for sharing

```powershell
flutter build windows        # build\windows\x64\runner\Release\ (copy the whole folder)
flutter build apk --release  # build\app\outputs\flutter-apk\app-release.apk (install on Android)
```

## Install on an iPhone from Windows (no Mac)

iPhone apps can only be built on a Mac. The workflow
[`.github/workflows/money-manager-flutter.yml`](../.github/workflows/money-manager-flutter.yml) builds
on a free GitHub macOS runner, and you install the result from Windows with Sideloadly.

1. Push the `Lab` folder to a GitHub repository. Pushes that change `money-manager-flutter/` start the
   workflow, or you can start it from the **Actions** tab (**Run workflow**). It takes about 15 minutes.
2. Open the finished run and download the **MoneyManager-flutter-unsigned-ipa** artifact. Unzip it to
   get `MoneyManager-unsigned.ipa`.
3. On Windows, install **iTunes** and **iCloud** using the installers from apple.com, not the Microsoft
   Store versions. Then install [Sideloadly](https://sideloadly.io).
4. Connect the iPhone by USB, unlock it, and tap **Trust**. In Sideloadly, drop in the `.ipa`, enter your
   Apple ID, and click **Start**. Sideloadly signs the app with your Apple ID and installs it.
5. On the iPhone:
   - Go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**.
   - On iOS 16 and later, also turn on **Settings → Privacy & Security → Developer Mode** and restart
     when asked.

With a free Apple ID the app stops opening after **7 days**. To renew it, run Sideloadly again with the
same `.ipa`; your data is kept. A free Apple ID can have at most 3 sideloaded apps at a time. A paid
Apple Developer account ($99/year) removes the 7-day limit and lets you use TestFlight.

On iPhone, receipts are read with Google ML Kit, which is usually more accurate than Windows OCR. The
camera option scans receipts directly.

## Project layout

```
lib/
├── main.dart                     # app start: database, notifications, theme
├── models/                       # MoneyTransaction, Budget, categories
├── data/app_database.dart        # SQLite schema and queries
├── services/
│   ├── ocr_service.dart          # ML Kit (mobile) / Windows OCR (desktop)
│   ├── receipt_parser.dart       # OCR lines -> total, date, merchant, category
│   ├── budget_analyzer.dart      # spent, pace projection, warning levels
│   └── notification_service.dart
├── state/app_state.dart          # ChangeNotifier holding data; budget alert de-duplication
└── ui/                           # Overview, History, Budgets, Settings, editor, capture flow
test/                             # unit and integration tests (+ fixtures/receipt_en.png)
```

Amounts are stored as integers in minor units (amount × 100), so there are no floating-point rounding
errors.
