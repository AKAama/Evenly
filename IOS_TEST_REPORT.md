# Evenly iOS 测试执行报告

执行日期：2026-06-24  
执行范围：方案 A，基于当前代码真实状态进行文档补全、构建验证、test action 探测和模拟器启动冒烟。  
执行人：Codex

## 1. 结论

本次验证确认 iOS 工程可以在 iPhone 17 / iOS 26.3.1 模拟器目标下成功构建，并且构建产物可以安装、启动到可用首屏。拿到测试账号后，已完成登录、账本切换、账单展示、分账结果展示和确认按钮的真实联调验证。已新增 XCTest / UI Test target，`xcodebuild test` 已通过。

## 2. 环境

| 项目 | 值 |
| --- | --- |
| 工作目录 | `/Users/alex_yehui/Projects/evenly-platform/Evenly` |
| Xcode project | `/Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj` |
| Scheme | `Evenly` |
| Bundle ID | `com.yhma.Evenly` |
| 模拟器 | iPhone 17 |
| 模拟器系统 | iOS 26.3.1 |
| 设备 UDID | `E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5` |
| 后端 | `http://localhost:8000` / `http://192.168.124.14:8000` |
| QA 账本 | `Codex QA iOS 20260624-212942` |

## 3. 执行记录

### 3.1 Scheme 探测

命令：

```bash
xcodebuild -list -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj
```

结果：PASS

关键信息：

- Targets：`Evenly`、`EvenlyTests`、`EvenlyUITests`
- Build Configurations：`Debug`、`Release`
- Schemes：`Evenly`

### 3.2 构建验证

第一次命令：

```bash
xcodebuild \
  -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj \
  -scheme Evenly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3' \
  build
```

结果：BLOCKED

原因：本机可用模拟器系统为 iOS 26.3.1，不是 26.3。Xcode 返回 `Unable to find a device matching the provided destination specifier`。

修正后命令：

```bash
xcodebuild \
  -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj \
  -scheme Evenly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' \
  build
```

结果：PASS

关键输出：

```text
** BUILD SUCCEEDED **
```

观察到的非阻塞警告：

- `AccentColor` 不存在于 asset catalog。
- `Metadata extraction skipped. No AppIntents.framework dependency found.`
- `No AppShortcuts found - Skipping.`

### 3.3 XCTest / UI Test

命令：

```bash
xcodebuild \
  -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj \
  -scheme Evenly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' \
  test
```

结果：PASS

关键输出：

```text
** TEST SUCCEEDED **
Test case 'EvenlyTests.testSanity()' passed
Test case 'EvenlyUITests.testLaunchShowsUsableEntryPoint()' passed
```

结论：

- `EvenlyTests` 单元测试 target 已配置。
- `EvenlyUITests` UI Test target 已配置。
- 当前 UI 冒烟测试兼容未登录首屏和已登录账本 Tab 首屏。

### 3.4 模拟器安装与启动冒烟

命令：

```bash
xcrun simctl boot E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 || true
xcrun simctl bootstatus E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 -b
xcrun simctl install E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 \
  /Users/alex_yehui/Library/Developer/Xcode/DerivedData/Evenly-bvvifgdnreqgmaderluoerzsgond/Build/Products/Debug-iphonesimulator/Evenly.app
xcrun simctl launch E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 com.yhma.Evenly
sleep 3
xcrun simctl io E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 screenshot \
  /Users/alex_yehui/Projects/evenly-platform/Evenly/ios-smoke-login.png
```

结果：PASS

关键输出：

```text
com.yhma.Evenly: 94142
Wrote screenshot to: /Users/alex_yehui/Projects/evenly-platform/Evenly/ios-smoke-login.png
```

截图证据：

![iOS smoke login](/Users/alex_yehui/Projects/evenly-platform/Evenly/ios-smoke-login.png)

验证结果：

- app 安装成功。
- app 启动成功。
- 未登录态展示 Evenly 登录页。
- 登录按钮在空表单状态下置灰。
- 密码输入框显示眼睛按钮。

### 3.5 本地后端与账号验证

结果：PASS

验证内容：

- `GET /health` 在 `localhost:8000` 返回 `{"status":"healthy"}`。
- `GET /health` 在 `192.168.124.14:8000` 返回 `{"status":"healthy"}`。
- 四个测试账号均可通过 `POST /auth/login` 登录。
- `aj@qq.com` 登录 iOS app 成功，进入账本页。

### 3.6 QA 数据准备

结果：PASS

已创建/使用：

- 账本：`Codex QA iOS 20260624-212942`
- 成员：`aj@qq.com`、`zyx@qq.com`、`dd@qq.com`、`111@qq.com`
- pending 账单：`Codex QA 晚餐 213035`，金额 `¥120`
- confirmed 账单：`Codex QA 车费 213055`，金额 `¥80`

后端问题修复后补测：

- 添加临时成员返回 `201`。
- 返回数据包含 `user_id: null`、`is_temporary: true` 和临时成员名称。
- 已定位原因为线上数据库 `ledger_members.user_id` 仍为 `NOT NULL` 且缺少临时成员相关约束/默认值。

### 3.7 iOS 联调验证

结果：PASS / PARTIAL

已验证通过：

- 登录成功后进入账本页。
- 账本抽屉可打开并切换到 QA 账本。
- 修复解码问题后，账单列表显示 confirmed 和 pending 账单。
- pending 账单对当前用户展示“拒绝/确认”按钮。
- 点击“确认”后，UI 显示“你已确认”，后端确认记录同步增加。
- 分账结果显示 4 名成员的应收/应付金额。

部分验证：

- 结算方案接口返回 3 条记录；修复后 UI 不再显示 `Failed to parse response`。受当前 Computer Use 工具缺少滚动动作限制，未完整滚动查看结算方案列表项。

### 3.8 本次修复

修复文件：

- `Evenly/API/APIClient.swift`
- `Evenly/API/APIModels.swift`

修复内容：

- 日期解码新增 `yyyy-MM-dd`，兼容后端 `expense_date`。
- 新增 flexible decimal 解码，兼容后端以字符串返回金额。
- 为账单、账单分摊、结算方案、结算记录等响应模型补充自定义 `init(from:)`。

## 4. 未执行项与原因

| 范围 | 状态 | 原因 |
| --- | --- | --- |
| 自动化单元测试 | PASS | 已新增 `EvenlyTests` 并通过 `xcodebuild test` |
| 自动化 UI 测试 | PASS | 已新增 `EvenlyUITests` 并通过 UI 冒烟测试 |
| 登录成功链路 | PASS | 已用测试账号验证 |
| 注册验证码链路 | BLOCKED | 需要可控邮箱验证码服务 |
| 账本 CRUD | PARTIAL | 已验证创建/切换；删除未测 |
| 成员管理 | PARTIAL | 注册成员和临时成员接口已验证；删除成员未测 |
| 账单创建/删除 | PARTIAL | 已通过 API 创建并在 iOS 展示；删除未测 |
| 确认/否决 | PARTIAL | 已验证确认；否决未测 |
| 结算方案/历史 | PARTIAL | 接口返回正常；UI 列表受滚动能力限制未完整查看 |
| 修改密码 | BLOCKED | 需要有效登录账号 |

## 5. 风险与建议

### 5.1 当前风险

- Debug 默认连接 `localhost:8000`，本次模拟器验证可访问本机后端；真机需要改为局域网或远端地址。
- 业务全链路仍未完全覆盖，删除、否决、修改密码、数据导出等路径待测。
- Asset Catalog 缺少 `AccentColor`，建议补齐以消除构建警告。
- 隐私政策和服务条款仍为占位链接。
- 自动化测试目前只有基础冒烟用例，核心业务回归仍以手测矩阵为主。

### 5.2 下一步建议

1. 准备一组固定测试账号：Owner、Member、未加入用户。
2. 准备一个可重置的测试后端环境和测试账本数据。
3. 按 `TEST_CASES.md` 执行 BLOCKED 项，并把实际结果回填。
4. 在现有 XCTest / UI Test target 上继续补充金额输入、分账计算、登录页和账本空状态测试。
