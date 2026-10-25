# Money Manager (iOS)

A personal money manager for iPhone, written in SwiftUI. Scan a receipt or invoice with the camera
(or import a photo), check the amount it reads, and save it to your history. Set monthly budgets
and get warned before and when you go over them.

Everything runs on the device. There's no server, no account, and no API keys.

## Features

- **Receipt and invoice capture.** Uses Apple's document scanner (edge detection, crop, perspective fix)
  or a photo from your library.
- **On-device OCR** with the Vision framework (English and Vietnamese). The parser finds the total
  (`TOTAL`, `Grand total`, `Tổng cộng`, `Thanh toán`, …), the date, and the merchant, and guesses a category.
  It skips subtotal, tax, cash and change lines, and understands `1,234.56`, `1.234,56` and `125.000đ`.
- **Review before saving.** Scanned values open in an editor. The receipt image is kept with the transaction.
- **History** grouped by day, with search, an income/expense filter, edit, and swipe-to-delete.
- **Overview** for any month: amount spent, income, balance, spending by category, and daily spending
  compared with your daily budget.
- **Budgets** per month, either for all spending or for one category, with a warning level you can change.
  - **Exceeded**: you've spent the limit or more.
  - **Warning**: you've passed the warning level (80% by default). Shows how much you can still spend per day.
  - **Spending fast**: you're under the warning level, but at your current daily pace you'll go over by month end.
  - A local notification is sent the first time a budget reaches *warning* or *exceeded* each month.
- **CSV export** for backup, from Settings.
- **Local storage** with SwiftData (SQLite on the device). Receipt images are stored outside the database.

## Requirements

- iOS 17+
- To build locally: a Mac with Xcode 15 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  (`brew install xcodegen`)

## Run it (on a Mac)

```bash
cd money-manager
xcodegen generate          # creates MoneyManager.xcodeproj from project.yml
open MoneyManager.xcodeproj
```

In Xcode, select the **MoneyManager** target. Under **Signing & Capabilities**, choose your team
(a free Apple ID works) and change the bundle ID if you need to, for example `com.yourname.moneymanager`.
Then pick your iPhone and press **Run**.

The camera scanner needs a real device. In the Simulator, use **Import from Photos**: drag a receipt
image into the Simulator window to add it to the photo library.

Run the tests with `Cmd+U`, or:

```bash
xcodebuild test -project MoneyManager.xcodeproj -scheme MoneyManager \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

## Deploy without a Mac (from Windows)

The workflow [`.github/workflows/money-manager-ios.yml`](../.github/workflows/money-manager-ios.yml)
runs the tests on a GitHub macOS runner and builds an **unsigned `.ipa`**.

1. Push this repo to GitHub. The workflow runs on every change under `money-manager/`
   (you can also start it from the **Actions** tab).
2. Download the `MoneyManager-unsigned-ipa` artifact from the workflow run.
3. Install [Sideloadly](https://sideloadly.io) on Windows, connect your iPhone, drop the `.ipa` in,
   and sign in with your Apple ID. Sideloadly signs the app and installs it.
4. On the iPhone, go to **Settings → General → VPN & Device Management** and trust your Apple ID.

With a free Apple ID, the app must be re-signed every 7 days; repeat step 3. Your data stays on the
phone as long as you don't delete the app. A paid Apple Developer account ($99/year) gives 1-year
signing and lets you distribute through **TestFlight** (Xcode → Product → Archive → Distribute).

## Project layout

```
money-manager/
├── project.yml                     # XcodeGen spec (targets, Info.plist keys, permissions)
├── MoneyManager/
│   ├── App/                        # App entry, notification delegate, settings keys
│   ├── Models/                     # SwiftData models: TransactionRecord, Budget, categories
│   ├── Services/
│   │   ├── ReceiptTextRecognizer   # Vision OCR -> text lines with positions
│   │   ├── ReceiptParser           # lines -> total, date, merchant, category
│   │   ├── BudgetAnalyzer          # pure budget math (spent, pace projection, levels)
│   │   └── BudgetMonitor           # runs the analyzer after saves, posts notifications
│   ├── Views/                      # Overview, History, Budgets, Settings, editor, capture flow
│   ├── Utilities/                  # formatting, image compression, CSV export
│   └── Resources/Assets.xcassets
└── MoneyManagerTests/              # parser and budget analyzer unit tests
```

## Customizing

- **Receipt keywords.** Edit the keyword lists in `ReceiptParser.swift` to add total labels or
  merchant-to-category rules for the shops you use.
- **Currency.** Change it in Settings. The default is your device's region currency.
- **Moving to cloud sync later.** SwiftData supports CloudKit. Add the iCloud capability and pass a
  `ModelConfiguration` with `cloudKitDatabase: .automatic`. The models already have default values
  for every property, which CloudKit requires.
