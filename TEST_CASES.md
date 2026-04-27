# Evenly 测试用例

## 测试环境
- 后端: http://1.94.184.24:8000
- 数据库: 华为云 PostgreSQL (1.94.184.24)

---

## 后端 API 测试用例

### 1. 账本管理

| 用例ID | API | 方法 | 测试数据 | 预期结果 | 实际结果 | 状态 |
|--------|-----|------|----------|----------|----------|------|
| TC-001 | POST /ledgers | 创建账本(无同名) | name: "测试账本1" | 201 Created | | |
| TC-002 | POST /ledgers | 创建同名账本 | name: "测试账本1" | 400 账本名称已存在 | | |
| TC-003 | POST /ledgers | 创建空名称 | name: "" | 422 验证错误 | | |
| TC-004 | GET /ledgers | 获取账本列表 | - | 200 返回账本列表 | | |
| TC-005 | GET /ledgers/{id} | 获取账本详情 | valid id | 200 返回详情+成员 | | |
| TC-006 | GET /ledgers/{id} | 获取不存在账本 | invalid id | 404 Not Found | | |
| TC-007 | DELETE /ledgers/{id} | 删除账本(Owner) | valid id | 204 No Content | | |
| TC-008 | DELETE /ledgers/{id} | 删除账本(非Owner) | valid id | 403 Forbidden | | |

### 2. 成员管理

| 用例ID | API | 方法 | 测试数据 | 预期结果 | 实际结果 | 状态 |
|--------|-----|------|----------|----------|----------|------|
| TC-009 | POST /ledgers/{id}/members | 添加已注册用户 | user_id: valid | 201 Created | | |
| TC-010 | POST /ledgers/{id}/members | 添加临时成员 | is_temporary: true, temporary_name: "临时用户" | 201 Created | | |
| TC-011 | POST /ledgers/{id}/members | 添加重复成员 | existing user_id | 400 User is already a member | | |
| TC-012 | GET /ledgers/{id}/members | 获取成员列表 | - | 200 返回成员列表 | | |
| TC-013 | DELETE /ledgers/{id}/members/{user_id} | 删除成员(Owner) | valid user_id | 204 No Content | | |

### 3. 支出管理

| 用例ID | API | 方法 | 测试数据 | 预期结果 | 实际结果 | 状态 |
|--------|-----|------|----------|----------|----------|------|
| TC-014 | POST /ledgers/{id}/expenses | 创建支出 | title: "测试晚餐", amount: 100 | 201 Created | | |
| TC-015 | GET /ledgers/{id}/expenses | 获取支出列表 | - | 200 返回列表 | | |
| TC-016 | DELETE /ledgers/{id}/expenses/{expense_id} | 删除支出 | valid expense_id | 204 No Content | | |

### 4. 结算

| 用例ID | API | 方法 | 测试数据 | 预期结果 | 实际结果 | 状态 |
|--------|-----|------|----------|----------|----------|------|
| TC-017 | GET /ledgers/{id}/settlements | 获取结算方案 | - | 200 返回方案 | | |
| TC-018 | POST /ledgers/{id}/settlements | 确认结算 | from, to, amount | 201 Created | | |

### 5. 用户搜索

| 用例ID | API | 方法 | 测试数据 | 预期结果 | 实际结果 | 状态 |
|--------|-----|------|----------|----------|----------|------|
| TC-019 | GET /users/search | 搜索已注册用户 | q: valid@email.com | 200 返回用户 | | |
| TC-020 | GET /users/search | 搜索不存在用户 | q: notexist@test.com | 200 返回空列表 | | |

---

## 测试记录

### 测试人: Yufi
### 测试日期: 2026-03-07

| 用例ID | 测试结果 | 问题记录 | 修复方案 |
|--------|----------|----------|----------|
| | | | |
