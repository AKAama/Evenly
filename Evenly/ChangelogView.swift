import SwiftUI

struct ChangelogEntry: Identifiable {
    let id: String
    let date: String
    let title: String
    let items: [String]

    static let all: [ChangelogEntry] = [
        ChangelogEntry(
            id: "2026.07.08",
            date: "2026 年 7 月 8 日",
            title: "记账与结算体验更新",
            items: [
                "重新设计新建账单，新增餐饮、交通、住宿等快捷分类与明细选项。",
                "优化付款人与参与人选择，通过头像和清晰状态快速完成多人账单设置。",
                "统一账本与弹出页面的视觉风格，并完善深色模式显示效果。",
                "账户头像支持查看大图，以及裁剪、缩放和旋转后更换。",
                "重新设计转账流向，清晰展示付款人、收款人及待转金额。",
            ]
        ),
        ChangelogEntry(
            id: "2026.07.05",
            date: "2026 年 7 月 5 日",
            title: "协作与账户体验更新",
            items: [
                "新增唯一用户名，支持使用用户名或邮箱登录。",
                "新增账本邀请流程，被邀请者接受后才会正式加入。",
                "收紧账本、成员和账单删除权限，普通成员可安全退出账本。",
                "账单创建者无需重复确认，并精简待结算与历史结算展示。",
                "新增本地使用模式、成员头像、账单范围筛选及多处界面优化。",
            ]
        ),
        ChangelogEntry(
            id: "2026.06.28",
            date: "2026 年 6 月 28 日",
            title: "共享账本稳定性更新",
            items: [
                "支持临时成员参与账单分摊。",
                "优化付款人和成员身份匹配，修复部分账单无法创建的问题。",
                "完善头像上传、显示与失败提示。",
                "优化结算方案展示及账本成员刷新。",
            ]
        ),
        ChangelogEntry(
            id: "2026.06.14",
            date: "2026 年 6 月 14 日",
            title: "Evenly 初始版本",
            items: [
                "支持创建共享账本、添加成员和记录多人账单。",
                "支持成员确认、自动分摊和结算建议。",
                "支持账户注册、登录和个人资料管理。",
            ]
        ),
    ]
}

struct ChangelogView: View {
    var body: some View {
        List(ChangelogEntry.all) { entry in
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.title)
                        .font(.headline)
                    ForEach(entry.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(entry.date)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("更新日志")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ChangelogView() }
}
