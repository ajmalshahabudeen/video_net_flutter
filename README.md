# Video Net Flutter

A Neo-Brutalist Android application for scanning local networks, discovering SMB shares, browsing files, and streaming video content directly over the network.

## Features

- **Network Scanner**: Scans the local subnet for active SMB hosts (ports 445/139).
- **SMB Authentication**: Securely connects to SMB shares and saves credentials locally for future use.
- **File Browser**: Browse folders and files within SMB shares.
- **Video Player**: Streams video files directly from SMB shares using a local HTTP proxy with range-request support for seamless seeking and 4K playback.
- **Neo-Brutalist Design**: Features a raw, high-contrast aesthetic with monospaced typography, thick borders, and hard shadows.

## Basic Flutter Commands

Here are some basic commands to work with this project:

- **Get Dependencies**:
  ```bash
  flutter pub get
  ```

- **Run the App** (requires an Android device/emulator):
  ```bash
  flutter run
  ```

- **Analyze Code** (check for linting errors):
  ```bash
  flutter analyze
  ```

- **Build APK (Debug)**:
  ```bash
  flutter build apk --debug
  ```

- **Build APK (Release)**:
  ```bash
  flutter build apk --release
  ```

## Architecture Notes
The app utilizes `media_kit` for robust video playback and `smb_connect` for SMB client capabilities. To overcome the lack of direct SMB streaming in `media_kit`, the app spawns a local `dart:io HttpServer` proxy that intercepts media requests and pipes data directly from the SMB stream, supporting HTTP Range requests for seeking.
