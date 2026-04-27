# Evenly iOS 开发文档

## 本次实现的功能

### 1. 支出确认状态显示

在账本详情页 (LedgerDetailView) 的账单列表中，现在会显示每个成员的确认状态：

- ✅ **已确认** - 绿色勾选图标 + "已确认" 文字
- ⏳ **待确认** - 橙色沙漏图标 + "待确认" 文字  
- ❌ **已否决** - 红色叉号图标 + "已否决" 文字

每个参与支出的人员都会显示其个人确认状态。

### 2. 成员头像显示

在成员管理页面 (AddMemberView) 的 MemberRowView 中，现在会显示成员头像：

- 如果成员有头像 URL：显示 AsyncImage 异步加载头像
- 如果成员没有头像：显示首字母头像（临时成员显示橙色图标）

---

## 改动文件列表

### 新增/修改的 Swift 文件

1. **Expense.swift**
   - 新增 `confirmations: [String: ConfirmationStatus]` 字段存储成员确认状态
   - 新增 `ConfirmationStatus` 枚举 (`pending`, `confirmed`, `rejected`)
   - 新增 `confirmationStatus(for:)` 方法获取特定成员的确认状态
   - 更新 `init(from:)` 初始化器以解析 API 返回的 confirmations 数据

2. **LedgerDetailView.swift**
   - 新增 `ConfirmationStatusRow` 视图组件
   - 在账单列表中展示确认状态区域
   - 为每个参与者显示对应的确认状态图标和文字

3. **AddMemberView.swift**
   - 修改 `MemberRowView` 添加头像显示功能
   - 新增 `avatarView` 计算属性用于显示头像或首字母
   - 新增 `fallbackAvatar` 属性用于无头像时的显示
   - 新增 `avatarUrl` 状态变量存储头像 URL

4. **LedgerStore.swift**
   - 新增 `MemberInfo` 结构体，包含 `avatarUrl` 字段
   - 更新 `fetchMemberInfo` 方法以返回头像 URL

---

## 待实现功能

### 高优先级

1. **确认/否决支出操作**
   - 在支出详情页添加"确认"和"否决"按钮
   - 调用后端 API (`POST /api/expenses/{id}/confirm`) 更新确认状态
   - 确认/否决后刷新支出列表

2. **头像缓存**
   - 实现本地头像缓存，避免重复网络请求
   - 使用 NSCache 或本地存储

3. **成员头像在更多页面显示**
   - 在分账结果页面显示成员头像
   - 在结算转账方案页面显示成员头像

### 中优先级

4. **支出筛选**
   - 按确认状态筛选支出（全部/已确认/待确认/已否决）

5. **推送通知**
   - 当有新支出时推送通知提醒成员确认

6. **离线支持**
   - 离线时缓存数据，联网后同步

---

## 技术说明

### API 集成

- 确认状态数据来自 `ExpenseWithDetails` 响应中的 `confirmations` 字段
- 成员头像 URL 来自 `MemberResponse.user.avatarUrl`

### 状态管理

- 使用 SwiftUI 的 `@State` 和 `@Published` 管理本地状态
- 确认状态存储在 `Expense.confirmations` 字典中，key 为 userId
