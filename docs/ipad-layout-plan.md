# Evenly iPad 端计划（`feature/ipad-layout`）

**原则：手机端布局与交互默认不动；iPad 用 `UIDevice.userInterfaceIdiom == .pad` 单独走壳。**

后端 **不需要改**：同一套 JWT REST API；iPad 只是展示与导航密度不同。

## 目标

| 场景 | 期望 |
| --- | --- |
| iPhone | 现有 `TabView`（账本 / 设置）完全保持 |
| iPad 竖/横 | `NavigationSplitView`：侧栏账本列表 + 详情区当前账本 |
| 平台运营号 | 暂仍用 `PlatformConsoleRootView`（可二期再做宽屏） |
| 游客模式 | 暂仍用 `GuestModeView`（可二期加宽屏画布） |

## 已落骨架

- `EvenlyDeviceLayout.swift` — `isPadIdiom`、列宽常量  
- `IPadAppShell.swift` — split + 侧栏选账本 → `LedgerStore.setCurrentLedger`  
- `ContentView` — 仅在 pad idiom 切换到 `IPadAppShell`

## 后续迭代（按优先级）

1. **详情区**真正吃满宽屏：工具栏、记一笔 sheet 用 `presentationDetents` / 中等宽度 form  
2. **登录 / 注册** 在 iPad 上限制 `maxWidth` 居中（避免超宽输入条）  
3. **Ledger 详情** 横屏可考虑双栏：账单列表 | 结算/成员  
4. **Apple HIG**：系统 List/Sidebar、材料与弹簧（见 apple-design skill），避免 fintech 营销卡  
5. **平台运营 iPad** 另开任务  

## 参考（Nixtio）

Nixtio 是 Miami 设计机构（Dribbble 作品集：金融 Dashboard、Wallet 等），**不是**开源 skill 或 Apple 官方指南。

可借鉴：

- 宽屏信息层级（主数字 + 次要列表）  
- 卡片与留白的节奏  

慎用：

- 偏营销 / Crypto 风的装饰  
- 与系统原生冲突的重阴影堆叠  

**Evenly iPad 主参考仍是：** Apple HIG（sidebar + split）+ 现有 `EvenlyStyle` + `apple-design` skill 的流体与克制。

## 开发注意

- 判断设备用 **`isPadIdiom`**，不要用 `horizontalSizeClass == .regular` 当「仅 iPad」（大屏 iPhone 横屏也是 regular）。  
- 新文件在 `Evenly/` 下即可（Xcode File System Sync 自动收录）。  
- 合并前请用 **iPad 模拟器 + iPhone 模拟器** 各跑一遍主路径。
