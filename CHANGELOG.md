# Changelog

## 2026-07-10 — 语音静音自动结束

- 用户开口后连续静音 1.8 秒会自动结束录音并生成草稿，仍可手动停止。
- 更新蓝牙麦克风路由选项为 `allowBluetoothHFP`，消除弃用警告。

## 2026-07-10 — 账单类别图标

- 类别预设会把类别和图标同步保存到共享账单。
- 新增 SF Symbols 与 Emoji 图标选择器，账单列表显示每笔账单自己的图标。
- 旧账单继续使用默认金额图标。

## 2026-07-10

### Added

- Added authenticated WebSocket support for realtime voice-expense sessions.
- Added live partial/final transcription and spoken-input examples in the expense form.
- Added regression coverage for WebSocket URL construction, audio conversion, and voice-session state.

### Changed

- Replaced temporary M4A upload recording with streamed 16 kHz mono PCM capture.
- Improved voice-session stop/cancel behavior and background audio sending.
- Refined expense and settlement navigation and billing interactions.
