# Changelog

All notable changes to the `OpenVidu Flutter` project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Initial planning and design.

## [0.0.14] - 2024-09-28

### Fixed

- Added missing type annotations across all source files
- Fixed missing return types for methods in RemoteParticipant, CustomWebSocket, and ApiClient
- Improved type safety with explicit variable declarations
- Enhanced code maintainability and IDE support

## [0.0.13] - 2024-09-28

### Changed

- Updated Android Gradle Plugin from 7.3.0 → 8.6.1
- Updated Kotlin version from 1.7.10 → 2.1.0
- Updated Gradle version from 7.6.3 → 8.7
- Updated compileSdk from flutter.compileSdkVersion → 36
- Updated targetSdkVersion from flutter.targetSdkVersion → 36
- Enhanced JVM arguments with better memory management
- Added compatibility flags for Android builds
- Enabled Gradle caching and parallel builds for better performance

### Build System Updates

- Resolved Kotlin compilation errors in Flutter tools
- Fixed compatibility issues between Flutter version and build tools
- Addressed plugin compatibility warnings (flutter_webrtc, path_provider_android, shared_preferences_android)

## [0.0.12] - 2024-08-19

### Changed

- Support up-to-date dependencies

## [0.0.11] - 2024-05-24

### Added

- Added isReaded flag to Message object
- Added onAddRemoteParticipant to the Session object

## [0.0.10] - 2024-05-22

### Changed

- Upgrade intl dependency
- Chat button is always visible now
- ChatBubble can be customized according to the user

## [0.0.9] - 2024-05-21

### Added

- Added chat support and chat screen in the example

## [0.0.8] - 2024-05-21

### Added

- Added some documentation

## [0.0.7] - 2024-05-21

### Added

- Added support for a customClient in websocket

## [0.0.6] - 2024-05-21

### Added

- Added support for bad certificate

## [0.0.5] - 2024-05-20

### Fixed

- Fixed homepage url

## [0.0.4] - 2024-05-20

### Changed

- Refactorizations

## [0.0.3] - 2024-05-20

### Fixed

- Image url fixed

## [0.0.2] - 2024-05-20

### Fixed

- Fixed Warnings

## [0.0.1] - 2024-05-20

### Added

- Participant names are now displayed for each remote participant
- Managing changes in the flow of remote participants
- The status of the participant's microphone and camera is displayed
