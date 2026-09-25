# Be Ummati (iOS)

Native SwiftUI app for lectures, Al Qalam library, timed subtitles, and offline audio.

**Bundle ID:** `com.codefixr.pioneerpins`  
**Widgets:** `com.codefixr.pioneerpins.widgets`  
**App Group:** `group.com.codefixr.beummati`  
**Open:** `Nur.xcodeproj` in Xcode → scheme **Be Ummati**

## Home Screen widgets

Three WidgetKit widgets (Next Prayer, Ayah of the Day, Last Reading) live in target **Be Ummati Widgets**.

The main app writes snapshots via `WidgetSnapshot` into the App Group suite (and mirrors to `UserDefaults.standard`). Until App Groups is enabled on both App IDs in the Apple Developer portal / Xcode Signing & Capabilities, widgets show placeholders.

On device signing you also need App ID `com.codefixr.pioneerpins.widgets` (Apple’s free-tier App ID weekly limit can block first-time registration).

Mac Catalyst builds skip the widget extension (`platformFilter = ios`).

## Install for users (important)

iPhone cannot install a random `.ipa` like Android APKs. Stock iOS requires Apple signing.

| Method | Users need | Notes |
|--------|------------|--------|
| **TestFlight** (recommended) | Their Apple ID + invite link | No Mac; you push builds from Xcode/CI |
| **App Store** | Apple ID | Public distribution |
| **Ad‑hoc IPA** | Device UDID registered on your team | GitHub Release can host the IPA; ≤100 devices |
| **Raw IPA download** | Sideload tools + *their* Apple ID | Not “just open the file” |

GitHub Releases are great for **versioned builds** and notes — not for unrestricted one-tap install on any iPhone.

## Version bump

In Xcode: target **Be Ummati** → General → Version / Build  
(`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the project file)

## Android

See sibling repo: [bu-android](https://github.com/omer-ct/bu-android) — APKs can ship from GitHub Releases for true sideload.
