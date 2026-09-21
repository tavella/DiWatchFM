# DiWatchFM

A native, standalone Apple Watch audio player for [DI.FM](https://www.di.fm) (Digitally Imported), paired with a lightweight iOS companion app for credential syncing.

Built for watchOS 10 or later, DiWatchFM streams audio directly over Cellular, Wi-Fi, and Bluetooth without requiring an iPhone nearby.

---

## Features

### Standalone watchOS Experience (`DiWatchApp`)
* **Standalone Streaming**: Connects and streams directly over Apple Watch Cellular, Wi-Fi, or Bluetooth without requiring an iPhone nearby.
* **Audio Quality & Bitrate Modes**:
  * **320k MP3 (High)**: Maximum audio fidelity for Wi-Fi and high-bandwidth connections.
  * **128k AAC (Standard)**: Balanced audio quality and bandwidth usage.
  * **64k AAC-HE (Data Saver)**: Low-bandwidth streaming designed for workouts and weak cellular connections.
  * Bitrate selection is configurable in the in-app Settings menu.
* **Station Catalog & Filtering**:
  * Complete, alphabetically sorted DI.FM station catalog.
  * Search bar with real-time query filtering.
  * Genre filters (Trance, House, Techno, Progressive, Chillout, Ambient, etc.) to filter channels quickly.
  * Pinned favorites stored locally at the top of the channel list.
* **Now Playing Interface**:
  * Channel artwork background display.
  * Auto-scrolling marquee text for long song titles and artist names.
  * Digital Crown hardware volume control with haptic feedback.
  * Horizontal swipe gestures to switch stations.
  * System media controls integration using `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` for Control Center, Smart Stack, and Bluetooth headphone transport controls.
* **Track History & Social Voting**:
  * Track history view displaying recently played songs with timestamps and album artwork.
  * Like and dislike voting synced directly to the user's DI.FM account.
  * Historical song voting directly from the track history list.
* **On-Demand Shows & DJ Mixes**:
  * Browse the DI.FM catalog of resident DJ shows, weekly broadcasts, and mixes.
  * Episode browser with track titles, air dates, and descriptions.
  * Playback controls with network retry handling.
* **Resource Management**:
  * Background network watchdog that cleans up active audio buffers and network activity when paused.
  * Stream failover mechanism that cycles through fallback endpoints if primary servers stall.

### iOS Companion Experience
* **Credential Setup**: Allows entering credentials and Listen Keys on iOS rather than using the watchOS keyboard.
* **WatchConnectivity Syncing**: Syncs the DI.FM Listen Key and account credentials directly to the paired Apple Watch.
* **Password Manager Support**: Standard text fields compatible with iOS autofill and clipboard pasting.

### Security and Privacy
* **Keychain Storage**: Credentials (Listen Key, username, password, session tokens) are stored in the device Keychain using `Security.framework`.
* **Direct Network Requests**: No third-party telemetry, tracking, or proxy servers. All requests communicate directly between the device and DI.FM / AudioAddict endpoints.

---

## Requirements

* **Apple Watch**: watchOS 10.0 or later (watchOS 10 / 11 / 26+).
* **iPhone**: iOS 17.0 or later (for companion credential setup).
* **Xcode**: Xcode 15.0 or later (Swift 5.9+ / Swift 6).
* **DI.FM Subscription**: A valid [DI.FM](https://www.di.fm) Premium subscription and Listen Key (available under your DI.FM Player Settings).

---

## Architecture Overview

| Directory / File | Platform | Description |
| :--- | :--- | :--- |
| `DiWatchFM/` | watchOS | Standalone Apple Watch player, audio engine (`WatchAudioPlayer`), API client (`AudioAddictAPI`), and watchOS views. |
| `DiPhoneFM/` | iOS | Lightweight companion interface (`ContentView`), app entry (`DiPhoneFMApp`), and credential sync manager (`WatchSyncManager`). |
| `DiWatchFMTests/` | watchOS | Unit tests for API authentication and stream resolution. |
| `project.yml` | XcodeGen | Unified project specification generating `DiWatchFM.xcodeproj`. |

---

## Getting Started

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/<your-username>/DiFM-AW.git
   cd DiFM-AW
   ```

2. **Open in Xcode**:
   ```bash
   open DiWatchFM.xcodeproj
   ```

3. **Configure Signing**:
   * Select the project root in the Xcode Navigator.
   * Under **Signing & Capabilities**, select your personal Apple Developer Team for the targets.

4. **Build and Run**:
   * Connect your iPhone and Apple Watch.
   * Select the **DiWatchFM** scheme with your iPhone as destination. Building and running installs the companion app on your iPhone and automatically installs the watchOS app on your paired Apple Watch in tandem.
   * Open the **DiWatchFM** companion app on your iPhone, enter your DI.FM Listen Key and credentials, and tap **Sync to Apple Watch**.
   * Or, select the **DiWatchApp** scheme targeting your Apple Watch directly for watch-only development.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Disclaimer & Trademarks

This application is an independent, unofficial third-party open-source project. 

* **DI.FM**, **Digitally Imported**, and **AudioAddict** are registered trademarks of AudioAddict, Inc.
* This project is **not** affiliated with, maintained by, authorized by, or endorsed by AudioAddict, Inc.
* Audio streaming requires an active, paid DI.FM Premium subscription.
