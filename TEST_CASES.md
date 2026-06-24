# Evenly iOS 测试文档

最后更新：2026-06-24

本文档覆盖 Evenly iOS 端的功能测试、构建验证、冒烟测试和回归测试范围。当前工程已配置 XCTest / UI Test target，本文档同时记录自动化入口和手动功能测试矩阵。

## 1. 测试环境

### 1.1 本次验证环境

- macOS：本机 Codex 桌面环境
- Xcode：`/Applications/Xcode.app`
- 项目：`Evenly.xcodeproj`
- Scheme：`Evenly`
- Bundle ID：`com.yhma.Evenly`
- 模拟器：iPhone 17, iOS 26.3.1
- 测试日期：2026-06-24

### 1.2 后端环境

- Debug 默认地址：`http://localhost:8000`
- Release 默认地址：`https://evenly.ismyh.cn`
- 可覆盖配置：`Info.plist` 中的 `EVENLY_API_BASE_URL`

完整登录、注册、账本、成员、账单和结算链路需要可用后端、测试账号和可控验证码邮箱。

## 2. 测试类型

| 类型 | 目标 | 当前状态 |
| --- | --- | --- |
| 构建验证 | 确认 iOS app 可以编译 | 可执行 |
| XCTest / UI Test | 确认自动化测试 target 可构建并运行 | 可执行 |
| 模拟器启动冒烟 | 确认 app 可安装并进入首屏 | 可执行 |
| 手动功能测试 | 覆盖核心业务流程 | 需要测试账号和后端环境 |
| 接口联调测试 | 验证 iOS 与后端契约 | 需要稳定后端数据 |
| 回归测试 | 发布前验证核心路径无回退 | 以手测矩阵为准 |

## 3. 命令行验证

### 3.1 查看 scheme

```bash
xcodebuild -list -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj
```

预期：

- Targets 包含 `Evenly`
- Schemes 包含 `Evenly`

### 3.2 构建

```bash
xcodebuild \
  -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj \
  -scheme Evenly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' \
  build
```

预期：

- 退出码为 0。
- 输出包含 `** BUILD SUCCEEDED **`。

已知警告：

- `AccentColor` 不存在于 asset catalog。该警告不阻塞构建。
- `No AppIntents.framework dependency found`。当前 app 未使用 App Intents，不阻塞构建。

### 3.3 XCTest / UI Test

```bash
xcodebuild \
  -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj \
  -scheme Evenly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' \
  test
```

预期：

- 退出码为 0。
- 输出包含 `** TEST SUCCEEDED **`。
- `EvenlyTests.testSanity()` 通过。
- `EvenlyUITests.testLaunchShowsUsableEntryPoint()` 通过。

### 3.4 模拟器安装与启动

```bash
xcrun simctl boot E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 || true
xcrun simctl bootstatus E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 -b
xcrun simctl install E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 \
  /Users/alex_yehui/Library/Developer/Xcode/DerivedData/Evenly-bvvifgdnreqgmaderluoerzsgond/Build/Products/Debug-iphonesimulator/Evenly.app
xcrun simctl launch E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 com.yhma.Evenly
xcrun simctl io E6E2EBD8-92D6-4DC1-B8DA-6E6A507AF2B5 screenshot \
  /Users/alex_yehui/Projects/evenly-platform/Evenly/ios-smoke-login.png
```

预期：

- app 安装成功。
- app 启动成功并返回进程 ID。
- 未登录状态展示登录页。

## 4. 手动功能测试矩阵

状态说明：

- PASS：本次已验证通过。
- FAIL：本次已验证失败。
- PARTIAL：本次验证了一部分路径，仍有子路径或 UI 可见性未覆盖。
- BLOCKED：因环境、账号、数据或工程配置阻塞。
- NOT RUN：本次未执行。

### 4.1 启动与未登录态

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-SMOKE-001 | 冷启动进入首屏 | 安装后启动 app | 未登录时显示 Evenly 登录页 | PASS |
| IOS-SMOKE-002 | 登录按钮禁用 | 不输入邮箱或密码 | 登录按钮置灰且不可点击 | PASS |
| IOS-SMOKE-003 | 密码显示切换 | 点击密码输入框右侧眼睛按钮 | 密码明文/密文状态切换 | PASS |
| IOS-SMOKE-004 | 进入注册页 | 点击“立即注册” | 展示注册表单 | NOT RUN |

### 4.2 登录

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-AUTH-001 | 空表单校验 | 邮箱或密码为空 | 登录按钮禁用 | PASS |
| IOS-AUTH-002 | 错误账号登录 | 输入不存在账号或错误密码并登录 | 展示登录错误，不进入主界面 | BLOCKED |
| IOS-AUTH-003 | 正确账号登录 | 输入有效邮箱和密码并登录 | 进入账本 Tab，拉取账本列表 | PASS |
| IOS-AUTH-004 | Token 恢复登录 | 登录后重启 app | 自动恢复登录态或刷新当前用户 | PASS |
| IOS-AUTH-005 | 退出登录 | 设置页点击退出登录 | 清除 token 并回到登录页 | BLOCKED |

### 4.3 注册

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-REG-001 | 用户名格式校验 | 输入非法用户名 | 展示格式错误提示 | NOT RUN |
| IOS-REG-002 | 邮箱格式校验 | 输入非法邮箱 | 展示邮箱错误提示 | NOT RUN |
| IOS-REG-003 | 发送验证码 | 输入有效邮箱并点击发送验证码 | 按钮进入 loading，成功后出现验证码输入框 | BLOCKED |
| IOS-REG-004 | 密码长度校验 | 输入少于 6 位密码 | 展示密码长度提示 | NOT RUN |
| IOS-REG-005 | 确认密码校验 | 两次密码不一致 | 展示不一致提示，注册按钮禁用 | NOT RUN |
| IOS-REG-006 | 完成注册 | 填写全部有效信息和验证码 | 注册成功并返回登录页 | BLOCKED |

### 4.4 账本

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-LEDGER-001 | 无账本空状态 | 新账号登录且无账本 | 展示“暂无账本”和添加按钮 | BLOCKED |
| IOS-LEDGER-002 | 打开账本抽屉 | 点击左上角菜单 | 打开账本抽屉，可选择账本或新增 | PASS |
| IOS-LEDGER-003 | 新建空成员账本 | 输入账本名称并保存 | 创建成功，当前账本切换为新账本 | PASS |
| IOS-LEDGER-004 | 添加本地参与者 | 新建账本时输入非邮箱名字并添加 | 参与者列表出现本地成员 | BLOCKED |
| IOS-LEDGER-005 | 添加注册成员 | 输入已注册邮箱并添加 | 参与者列表出现注册成员 | PASS |
| IOS-LEDGER-006 | 添加未注册邮箱 | 输入未注册邮箱 | 弹出添加临时成员确认并成功添加 | PASS |
| IOS-LEDGER-007 | 重复参与者校验 | 添加重复名字或重复用户 | 展示重复提示，不重复入列 | BLOCKED |
| IOS-LEDGER-008 | 搜索账单 | 在账本详情搜索框输入关键字 | 账单列表按标题或付款人过滤 | NOT RUN |
| IOS-LEDGER-009 | 删除账本 | 从账本入口触发删除 | 删除成功后列表刷新 | BLOCKED |
| IOS-LEDGER-010 | 非 Owner 退出账本 | 非 Owner 点击退出账本 | 账本从当前列表移除 | BLOCKED |

### 4.5 成员管理

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-MEMBER-001 | 打开成员管理 | 账本菜单点击“管理成员” | 展示成员管理页和成员数量 | BLOCKED |
| IOS-MEMBER-002 | 搜索注册用户 | 输入已注册邮箱并搜索 | 展示用户邮箱、昵称、头像或默认头像 | BLOCKED |
| IOS-MEMBER-003 | 添加注册用户 | 点击搜索到的注册用户 | 添加成功并刷新成员列表 | BLOCKED |
| IOS-MEMBER-004 | 搜索未注册用户 | 输入不存在邮箱并搜索 | 展示可添加为临时成员 | BLOCKED |
| IOS-MEMBER-005 | 添加临时成员 | 输入临时成员名字并添加 | 添加成功并刷新成员列表 | PASS |
| IOS-MEMBER-006 | 删除成员 | 点击成员行删除按钮 | 成员被删除或后端返回权限错误 | BLOCKED |
| IOS-MEMBER-007 | 头像降级 | 用户头像 URL 为空或加载失败 | 显示首字母或默认头像 | BLOCKED |

### 4.6 账单

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-EXP-001 | 打开新建账单页 | 账本菜单点击“添加账单” | 展示账单名称、金额、付款人、参与人 | BLOCKED |
| IOS-EXP-002 | 无注册成员提示 | 账本仅有临时成员时添加账单 | 提示先添加已注册成员 | BLOCKED |
| IOS-EXP-003 | 金额格式限制 | 输入字母、多小数点或三位小数 | 自动过滤非法字符并最多保留两位小数 | BLOCKED |
| IOS-EXP-004 | 保存按钮禁用 | 名称、金额、付款人或参与人缺失 | 保存按钮禁用 | BLOCKED |
| IOS-EXP-005 | 付款人自动参与 | 选择付款人 | 付款人自动加入参与人且不能取消 | BLOCKED |
| IOS-EXP-006 | 创建账单 | 输入有效账单并保存 | 账单创建成功，列表新增 pending 账单 | PASS |
| IOS-EXP-007 | 删除账单 | 左滑或删除账单 | 账单删除成功或后端返回权限错误 | BLOCKED |

### 4.7 确认与否决

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-CONFIRM-001 | 参与人看到操作 | 登录用户是 pending 账单参与人 | 显示“拒绝”和“确认”按钮 | PASS |
| IOS-CONFIRM-002 | 非参与人不显示操作 | 登录用户不是账单参与人 | 不显示确认/拒绝按钮 | BLOCKED |
| IOS-CONFIRM-003 | 确认账单 | 点击“确认” | 按钮 loading，成功后显示“你已确认” | PASS |
| IOS-CONFIRM-004 | 拒绝账单 | 点击“拒绝” | 成功后显示“你已拒绝”，账单状态更新 | BLOCKED |
| IOS-CONFIRM-005 | 重复操作保护 | 已确认或已拒绝后刷新页面 | 不再显示操作按钮 | BLOCKED |
| IOS-CONFIRM-006 | 操作失败提示 | 后端返回错误 | 展示“操作失败”弹窗 | BLOCKED |

### 4.8 分账与结算

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-SETTLE-001 | 分账结果展示 | 账本有成员和账单 | 展示每人应收、应付或已结清 | PASS |
| IOS-SETTLE-002 | 空成员结果 | 账本无参与者 | 展示“暂无参与者” | BLOCKED |
| IOS-SETTLE-003 | 获取结算方案 | 打开账本详情 | 展示后端返回的结算指令 | PARTIAL |
| IOS-SETTLE-004 | 账目已结清 | 后端返回空结算方案 | 展示“账目已结清” | BLOCKED |
| IOS-SETTLE-005 | 确认结算 | 点击结算方案右侧确认按钮 | 记录结算并刷新方案和历史 | BLOCKED |
| IOS-SETTLE-006 | 结算记录 | 账本有结算历史 | 展示转账双方、金额和时间 | BLOCKED |
| IOS-SETTLE-007 | 结算接口失败 | 后端返回错误或断网 | 展示错误提示 | BLOCKED |

### 4.9 设置

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-SETTINGS-001 | 账户信息展示 | 登录后进入设置页 | 展示头像、显示名、用户名、邮箱 | BLOCKED |
| IOS-SETTINGS-002 | 主题切换 | 切换系统/浅色/深色 | UI 主题切换并保存 | BLOCKED |
| IOS-SETTINGS-003 | 修改密码校验 | 新密码小于 6 位或两次不一致 | 保存按钮禁用或展示提示 | BLOCKED |
| IOS-SETTINGS-004 | 修改密码成功 | 输入正确旧密码和有效新密码 | 修改成功并关闭弹窗 | BLOCKED |
| IOS-SETTINGS-005 | 修改密码失败 | 输入错误旧密码 | 展示错误信息 | BLOCKED |
| IOS-SETTINGS-006 | 关于链接 | 点击隐私政策/服务条款 | 打开外部链接 | BLOCKED |

### 4.10 数据管理

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-DATA-001 | 数据统计 | 进入数据管理页 | 展示账本数量、账单总数、参与者总数 | BLOCKED |
| IOS-DATA-002 | 无账本导出禁用 | 无账本时进入数据管理页 | 导出按钮禁用 | BLOCKED |
| IOS-DATA-003 | 导出账本 | 有账本时点击导出 | 出现文件导出器，导出纯文本 | BLOCKED |
| IOS-DATA-004 | 清除缓存 | 点击清除本地缓存并确认 | 清除 `CachedLedgers`，展示完成提示 | BLOCKED |

### 4.11 异常与兼容性

| ID | 用例 | 步骤 | 预期结果 | 状态 |
| --- | --- | --- | --- | --- |
| IOS-ERR-001 | 无 token 请求 | 清空 token 后触发需登录接口 | 显示未授权或回到登录态 | BLOCKED |
| IOS-ERR-002 | 后端不可达 | Debug 环境未启动后端并登录/拉取数据 | 展示网络错误，不崩溃 | BLOCKED |
| IOS-ERR-003 | Dynamic Type | 调大字体后浏览核心页面 | 关键文本不重叠，按钮可点击 | NOT RUN |
| IOS-ERR-004 | 横竖屏/iPad | 在 iPad 模拟器打开 app | 页面布局可用 | NOT RUN |
| IOS-ERR-005 | 冷启动恢复当前账本 | 选择账本后重启 app | 恢复上次当前账本或选择第一个账本 | BLOCKED |

## 5. 发布前回归清单

发布前至少执行以下路径：

1. 构建：`xcodebuild build` 成功。
2. 启动：模拟器安装并启动到登录页。
3. 登录：有效账号可登录并展示账本页。
4. 账本：创建账本、添加注册成员、添加临时成员、删除或退出账本。
5. 账单：创建账单、搜索账单、删除账单。
6. 确认：参与人确认和拒绝 pending 账单。
7. 结算：查看结算方案、确认结算、查看结算记录。
8. 设置：切换主题、修改密码、退出登录。
9. 数据：导出账本、清除本地缓存。
10. 异常：后端不可达、接口报错、无 token 等情况不崩溃。

## 6. 本次新增测试发现

| ID | 发现 | 影响 | 当前处理 |
| --- | --- | --- | --- |
| BUG-IOS-001 | 后端金额字段返回字符串，例如 `"20.00"`，iOS 直接解码为 `Decimal` 会失败 | 账单列表为空，结算方案显示 `Failed to parse response` | 已修复 iOS 解码，支持字符串/数字金额 |
| BUG-IOS-002 | 后端 `expense_date` 返回纯日期，例如 `"2026-06-24"`，iOS 日期解码器原先只支持时间戳 | 账单响应可能解析失败 | 已修复日期解码，支持 `yyyy-MM-dd` |
| BUG-BE-001 | 添加临时成员接口返回 503 `Database is not ready` | 临时成员添加路径不可用 | 未修复，需后端排查 |
| QA-LIMIT-001 | 当前 Computer Use 工具无法滚动 iOS 页面 | 结算方案 UI 只验证到不再解析失败，未完整看到列表项 | API 已验证返回 3 条结算方案 |

## 7. XCTest / UI Test target 配置建议

当前工程只有 `Evenly` app target，没有测试 target，所以 `xcodebuild test` 会返回 `Scheme Evenly is not currently configured for the test action.` 建议按下面方式配置：

1. 在 Xcode 中打开 `/Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj`。
2. 选择 `File -> New -> Target...`。
3. 新增 `Unit Testing Bundle`：
   - Product Name：`EvenlyTests`
   - Team：沿用 app target
   - Target to be Tested：`Evenly`
   - Language：Swift
4. 再新增 `UI Testing Bundle`：
   - Product Name：`EvenlyUITests`
   - Target Application：`Evenly`
   - Language：Swift
5. 打开 `Product -> Scheme -> Edit Scheme... -> Test`，确认 `EvenlyTests` 和 `EvenlyUITests` 都在 Test 列表中。
6. 给 app target 增加测试友好的依赖注入入口：
   - API base URL 继续使用 `EVENLY_API_BASE_URL`。
   - UI Test 可通过 launch arguments 传入测试账号或 mock 模式。
   - 网络层建议抽出 protocol，Unit Test 用 mock client，UI Test 用本地 mock server 或测试后端。
7. 初始用例建议：
   - Unit：金额字符串解码、纯日期解码、结算方案解码、分账计算、金额输入格式化。
   - UI：登录页空表单、成功登录、账本列表、账本详情、确认按钮、设置页退出登录。

命令行验证：

```bash
xcodebuild \
  -project /Users/alex_yehui/Projects/evenly-platform/Evenly/Evenly.xcodeproj \
  -scheme Evenly \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' \
  test
```

## 8. 自动化测试建议

当前未按方案 B 增加自动化测试基础设施。若后续需要，建议新增：

- Unit Tests：金额格式化、分账计算、请求模型转换、输入校验。
- UI Tests：登录页、注册页、空账本、新建账本、新建账单、设置页。
- Mock API：用本地 mock server 或 URLProtocol stub 替代真实后端。
- CI：在 GitHub Actions 或本机脚本中跑 `xcodebuild test`。
