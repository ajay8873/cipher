# Cipher (Khata) — Intelligent Automated Expense & Credit Tracker

[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-brightgreen.svg)](https://android.com)

**Cipher** (formerly Khata) is an open-source, 100% privacy-first automated expense and credit tracking application for Android. It uses intelligent **Bank SMS parsing** and a background **UPI Push Notification Listener** to automatically record your debits and incoming money credits in real time.

---

## 🌟 Key Features

### 1. 💬 Automated Bank SMS Tracker
- Parses incoming and historical bank SMS messages using high-accuracy native regex patterns.
- Automatically extracts **Amount (₹)**, **Merchant / Store Name**, **Date**, **Transaction Type (Debit vs Credit)**, and **Account Type (UPI, Bank, Credit Card)**.

### 2. 🔔 PhonePe & Multi-UPI Push Notification Listener
- Reads push notifications posted by major Indian UPI apps:
  - **PhonePe** (`com.phonepe.app`)
  - **Navi UPI** (`com.navi.passport`, `com.navi.app`)
  - **Google Pay** (`com.google.android.apps.nbu.paisa.user`)
  - **Paytm** (`net.one97.paytm`)
  - **CRED** (`com.dreamplug.credpay`)
  - **BHIM** (`in.org.npci.upiapp`)
  - **Slice**, **Jupiter**, **Super.money**, **MobiKwik**, **Amazon Pay**, and **Bajaj Pay**.
- Solves the common issue where bank SMS is delayed or missing for micro-UPI credits.

### 3. ⚡ Powerful Hybrid Deduplication Engine
- Prevents double-counting when **both** a Bank SMS and a Push Notification arrive for the same payment.
- Checks amount (±₹0.05) and transaction type within a rolling 5-minute window before creating a record.

### 4. 🪟 Real-Time System Overlay Window
- Displays a non-intrusive floating system overlay window over other apps immediately after a transaction occurs.
- Allows users to tag the **Purpose** (e.g. *"Dinner with friends"*) and **Recipient/Paid To** on the fly.

### 5. 📊 Visual Analytics & Category Breakdown
- **Today's Overview**: Real-time stats card showing today's spent vs today's received total.
- **Category Charts**: Interactive donut charts (`fl_chart`) with percentage distribution across categories (Food, Shopping, Bills, Transport, etc.).
- **Quick Date Filters**: Single-tap toggle for **Daily**, **Monthly**, **Last Month**, and **Custom Date Range (Calendar)**.
- **Non-Confusing Month Selector**: Dedicated Month & Year picker dialog for selecting monthly expense summaries without day grids.

### 6. 🔄 GitHub In-App Auto-Updater
- Automatically queries the GitHub Releases API on app startup.
- Displays an in-app update popup with release notes and a direct download link whenever a new APK version is released.

### 7. 🛡️ 100% On-Device Privacy
- All SMS messages, notifications, and transaction logs stay strictly on your local device inside an SQLite database (`khata_expenses.db`).
- Zero data collection, zero registration, and zero cloud requirement (optional Supabase sync can be enabled).

---

## 🛠️ Architecture & Tech Stack

- **Framework**: [Flutter 3.x](https://flutter.dev) (Dart 3.x)
- **Local Storage**: `sqflite` (SQLite), `shared_preferences`
- **SMS Listening**: `telephony`
- **Notification Listening**: `flutter_notification_listener`
- **Background Overlay**: `flutter_overlay_window`
- **Charts & Data Viz**: `fl_chart`
- **AI Fallback Engine**: DeepSeek API (Optional NLP parsing)
- **Cloud Sync**: Supabase Flutter SDK (Optional)

---

## 📱 Android Permission Requirements

| Permission | Purpose |
| :--- | :--- |
| `READ_SMS` & `RECEIVE_SMS` | Required to read and parse incoming bank transaction SMS messages |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Required to detect incoming UPI credits from PhonePe, GPay, Paytm & Navi |
| `SYSTEM_ALERT_WINDOW` | Required to open the quick transaction tagging overlay window over other apps |

---

## 🚀 Building & Running from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
- Android Studio / Android SDK (API 34+)
- JDK 17+

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/Sidhu1232/cipher-khata.git
   cd cipher-khata
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run in Debug Mode on connected Android device:
   ```bash
   flutter run -d <device_id>
   ```

4. Build Release APK:
   ```bash
   flutter build apk --release
   ```
   The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🌐 Deploying the Landing Page to Cloudflare Pages

The repository contains a production-ready static landing page in `web_landing/index.html`.

### To Deploy on Cloudflare Pages:
1. Connect your GitHub repository to **Cloudflare Pages**.
2. Set **Build Output Directory** to `web_landing`.
3. Set **Build Command** to empty (or `exit 0`).
4. Save and deploy! Your website will be live at `https://cipher-khata.pages.dev`.

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
