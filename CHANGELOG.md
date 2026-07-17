# Changelog

## 2026-07-17 — Sign in with Apple 合规

- 移除 Apple 登录后强制「设置用户名」弹窗；姓名/邮箱仅使用 Authentication Services 提供的信息。
- 用户名与显示名称改为账户设置中可选修改，不再阻塞进入 App。

## 2026-07-16 — 分享、确认开关与预估转账

- 新增账本小结分享图：可选支出、账单数、成员、转账流向、账单明细，勾选后预览并系统分享。
- 账单明细展示付款人与参与人；转账/明细对未确认相关条目灰色「未确认」标记。
- 账本级开关「需要成员确认账单」：创建时可选，成员页可改；关闭后记账即确认，待确认账单批量生效。
- 转账流向按已确认+待确认预估终局金额，确认前后金额一致，仅未确认相关行灰色提示。
- 本地模式账本上限 3 个等既有行为保持不变。

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
