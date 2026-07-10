# Changelog

## 2026-07-10

### Added

- Added authenticated WebSocket support for realtime voice-expense sessions.
- Added live partial/final transcription and spoken-input examples in the expense form.
- Added regression coverage for WebSocket URL construction, audio conversion, and voice-session state.

### Changed

- Replaced temporary M4A upload recording with streamed 16 kHz mono PCM capture.
- Improved voice-session stop/cancel behavior and background audio sending.
- Refined expense and settlement navigation and billing interactions.
