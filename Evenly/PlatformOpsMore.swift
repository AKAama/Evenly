//
//  PlatformOpsMore.swift
//  Evenly
//
//  Platform shell: 「我的」flat menu + ledger detail + badges + audit + platform users.
//  Visual language matches PlatformConsoleView (SAVO-inspired).
//

import SwiftUI
import UIKit

// MARK: - 我的（功能平铺，右下角 Tab 永远是「我的」）

struct PlatformMeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var showChangePassword = false
    @State private var showChangeDisplayName = false
    @State private var draftDisplayName = ""
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Cover + avatar (SAVO-style), role chip on cover — not next to name
                    ZStack(alignment: .bottomLeading) {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.12, green: 0.42, blue: 0.38),
                                            Color(red: 0.10, green: 0.35, blue: 0.32),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 112)
                                .overlay {
                                    GeometryReader { geo in
                                        Path { path in
                                            let step: CGFloat = 14
                                            var x: CGFloat = -geo.size.height
                                            while x < geo.size.width + geo.size.height {
                                                path.move(to: CGPoint(x: x, y: 0))
                                                path.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                                                x += step
                                            }
                                        }
                                        .stroke(Color.white.opacity(0.06), lineWidth: 8)
                                    }
                                }

                            Text("平台运营")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.18), in: Capsule())
                                .padding(.top, 14)
                                .padding(.trailing, 16)
                        }

                        RemoteAvatarView(
                            avatarUrl: auth.user?.avatarUrl,
                            localImage: auth.avatarImage,
                            fallbackText: auth.user?.resolvedDisplayName ?? "我",
                            size: 76,
                            fallbackBackground: PlatformStyle.accentPink,
                            fallbackForeground: .white
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                        .offset(y: 38)
                        .padding(.leading, 22)
                    }
                    .padding(.bottom, 44)

                    // Name (SAVO: big title only)
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            draftDisplayName = auth.user?.displayName ?? auth.user?.resolvedDisplayName ?? ""
                            withAnimation(.easeOut(duration: 0.18)) {
                                showChangeDisplayName = true
                                showChangePassword = false
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                Text(auth.user?.resolvedDisplayName ?? "平台账号")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(PlatformStyle.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PlatformStyle.textTertiary)
                                    .padding(6)
                                    .background(PlatformStyle.cardMuted, in: Circle())
                            }
                        }
                        .buttonStyle(PlatformPressStyle())

                        // SAVO-style identity chips: UID · @username · email (copy on tap)
                        FlowIdentityChips(
                            uid: shortUserId,
                            username: auth.user?.username,
                            email: auth.user?.email
                        )
                    }
                    .padding(.horizontal, 22)

                    if showChangeDisplayName {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("修改展示名")
                                .font(.system(size: 15, weight: .bold))
                            TextField("展示名称", text: $draftDisplayName)
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            HStack(spacing: 10) {
                                Button("取消") {
                                    withAnimation { showChangeDisplayName = false }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PlatformStyle.textSecondary)
                                Spacer()
                                blackCapsuleButton(isSaving ? "保存中…" : "保存展示名") {
                                    Task { await submitDisplayName() }
                                }
                                .frame(maxWidth: 160)
                                .disabled(isSaving || !canSubmitDisplayName)
                            }
                        }
                        .platformCard()
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Account settings (not ops)
                    Text("账号设置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PlatformStyle.textSecondary)
                        .padding(.horizontal, 22)
                        .padding(.top, 4)

                    VStack(spacing: 0) {
                        infoLine("账号类型", "平台运营")
                        Divider().padding(.leading, 16)
                        infoLine("分账", "不可参与用户账本")
                        Divider().padding(.leading, 16)
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showChangePassword.toggle()
                                if showChangePassword { showChangeDisplayName = false }
                            }
                        } label: {
                            HStack {
                                Text("修改密码")
                                    .foregroundStyle(PlatformStyle.textPrimary)
                                Spacer()
                                Text(showChangePassword ? "收起" : "设置")
                                    .foregroundStyle(PlatformStyle.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PlatformStyle.textTertiary)
                                    .rotationEffect(.degrees(showChangePassword ? 90 : 0))
                            }
                            .font(.system(size: 14))
                            .padding(16)
                        }
                        .buttonStyle(PlatformPressStyle())
                    }
                    .platformCard(padding: 0)
                    .padding(.horizontal, 20)

                    if showChangePassword {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("修改密码")
                                .font(.system(size: 15, weight: .bold))
                            SecureField("当前密码", text: $oldPassword)
                                .textContentType(.password)
                                .padding(12)
                                .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            SecureField("新密码（至少 6 位）", text: $newPassword)
                                .textContentType(.newPassword)
                                .padding(12)
                                .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            SecureField("确认新密码", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding(12)
                                .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            blackCapsuleButton(isSaving ? "保存中…" : "保存新密码") {
                                Task { await submitPasswordChange() }
                            }
                            .disabled(isSaving || !canSubmitPassword)
                        }
                        .platformCard()
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    blackCapsuleButton("退出登录", destructive: true) {
                        HapticManager.notificationOccurred(.warning)
                        auth.signOut()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(PlatformStyle.canvas)
            .navigationBarHidden(true)
            .alert(messageIsError ? "修改失败" : "已更新", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private var shortUserId: String? {
        guard let id = auth.user?.id else { return nil }
        let compact = id.replacingOccurrences(of: "-", with: "")
        return String(compact.prefix(12))
    }

    private func infoLine(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).foregroundStyle(PlatformStyle.textSecondary)
            Spacer()
            Text(v).fontWeight(.medium)
        }
        .font(.system(size: 14))
        .padding(16)
    }

    private var canSubmitPassword: Bool {
        !oldPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private var canSubmitDisplayName: Bool {
        !draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func clearPasswordFields() {
        oldPassword = ""
        newPassword = ""
        confirmPassword = ""
    }

    private func submitDisplayName() async {
        let name = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            messageIsError = true
            message = "展示名不能为空"
            return
        }
        isSaving = true
        defer { isSaving = false }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            auth.updateDisplayName(name) { error in
                if let error {
                    messageIsError = true
                    message = error.localizedDescription
                } else {
                    messageIsError = false
                    message = "展示名已更新"
                    showChangeDisplayName = false
                    HapticManager.notificationOccurred(.success)
                }
                cont.resume()
            }
        }
    }

    private func submitPasswordChange() async {
        guard canSubmitPassword else {
            messageIsError = true
            message = newPassword != confirmPassword ? "两次新密码不一致" : "新密码至少 6 位"
            return
        }
        isSaving = true
        defer { isSaving = false }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            auth.changePassword(oldPassword: oldPassword, newPassword: newPassword) { error in
                if let error {
                    messageIsError = true
                    message = error.localizedDescription
                } else {
                    messageIsError = false
                    message = "密码已修改"
                    showChangePassword = false
                    clearPasswordFields()
                    HapticManager.notificationOccurred(.success)
                }
                cont.resume()
            }
        }
    }
}

// MARK: - SAVO-style identity chips (UID / @user / email)

private struct FlowIdentityChips: View {
    let uid: String?
    let username: String?
    let email: String?
    @State private var toast: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: UID + @username (SAVO profile style)
            HStack(spacing: 8) {
                if let uid {
                    copyChip(prefix: "UID", value: uid, copyText: uid)
                }
                if let username {
                    copyChip(prefix: nil, value: "@\(username)", copyText: username)
                }
            }
            // Row 2: email alone so long addresses don't crush the row
            if let email {
                copyChip(prefix: nil, value: email, copyText: email)
            }
            if let toast {
                Text(toast)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PlatformStyle.accentGreen)
                    .transition(.opacity)
            }
        }
    }

    private func copyChip(prefix: String?, value: String, copyText: String) -> some View {
        Button {
            UIPasteboard.general.string = copyText
            withAnimation {
                toast = "已复制"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { toast = nil }
            }
            HapticManager.selection.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                if let prefix {
                    Text("\(prefix): \(value)")
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Text(value)
                        .font(.system(size: 12, weight: .medium))
                }
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PlatformStyle.textTertiary)
            }
            .foregroundStyle(PlatformStyle.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PlatformStyle.cardMuted, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(PlatformStyle.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PlatformPressStyle())
    }
}

// MARK: - Ledger overview

struct PlatformLedgerDetailSheet: View {
    let ledgerId: String
    let ledgerName: String
    @Environment(\.dismiss) private var dismiss
    @State private var overview: LedgerOverviewResponse?
    @State private var errorText: String?
    @State private var isLoading = true
    @State private var selectedExpense: ExpenseWithDetails?
    @State private var membersForExpense: [MemberResponse] = []

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载账本…")
                } else if let errorText {
                    ContentUnavailableView("加载失败", systemImage: "wifi.exclamationmark", description: Text(errorText))
                } else if let overview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                statBox("成员", "\(overview.ledger.members.filter { $0.status == "active" }.count)")
                                statBox("账单", "\(overview.expenses.count)")
                                let spend = overview.expenses
                                    .filter { $0.status != "rejected" }
                                    .reduce(Decimal.zero) { $0 + ($1.totalAmount - ($1.refundAmount ?? 0)) }
                                statBox("实付", spend.formattedCurrency)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("成员")
                                    .font(.system(size: 15, weight: .bold))
                                ForEach(overview.ledger.members, id: \.id) { m in
                                    HStack {
                                        Text(memberTitle(m))
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        if m.isTemporary {
                                            miniChip("临时", color: PlatformStyle.textSecondary)
                                        }
                                        Text(m.status)
                                            .font(.caption)
                                            .foregroundStyle(PlatformStyle.textTertiary)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .platformCard()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("账单")
                                    .font(.system(size: 15, weight: .bold))
                                if overview.expenses.isEmpty {
                                    Text("暂无账单")
                                        .foregroundStyle(PlatformStyle.textTertiary)
                                } else {
                                    ForEach(overview.expenses.prefix(80)) { e in
                                        Button {
                                            membersForExpense = overview.ledger.members
                                            selectedExpense = e
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(e.title)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(PlatformStyle.textPrimary)
                                                    Text(expenseStatusLabel(e.status))
                                                        .font(.caption)
                                                        .foregroundStyle(PlatformStyle.textTertiary)
                                                }
                                                Spacer()
                                                let net = e.totalAmount - (e.refundAmount ?? 0)
                                                Text(net.formattedCurrency)
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundStyle(PlatformStyle.textPrimary)
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(PlatformStyle.textTertiary)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(PlatformPressStyle())
                                        Divider().opacity(0.4)
                                    }
                                }
                            }
                            .platformCard()

                            if !overview.settlementSuggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("结算建议")
                                        .font(.system(size: 15, weight: .bold))
                                    ForEach(Array(overview.settlementSuggestions.enumerated()), id: \.offset) { _, s in
                                        Text("\(s.fromUserName) → \(s.toUserName)  \(s.amount.formattedCurrency)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(PlatformStyle.textSecondary)
                                    }
                                }
                                .platformSoftCard()
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(PlatformStyle.canvas)
            .navigationTitle(ledgerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(item: $selectedExpense) { expense in
                PlatformExpenseDetailSheet(expense: expense, members: membersForExpense)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func expenseStatusLabel(_ status: String) -> String {
        switch status {
        case "confirmed": return "已确认"
        case "pending": return "待确认"
        case "rejected": return "已否决"
        default: return status
        }
    }

    private func memberTitle(_ m: MemberResponse) -> String {
        if let u = m.user {
            return u.publicDisplayName ?? u.displayName ?? u.username
        }
        return m.temporaryName ?? m.nickname ?? "成员"
    }

    private func statBox(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PlatformStyle.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .platformSoftCard(padding: 12)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            overview = try await APIClient.shared.get(APIEndpoints.adminLedgerOverview(id: ledgerId))
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Badges

/// Shared by list + editor sheet (must not be nested `private` inside the View).
private enum BadgeEditorMode: Identifiable {
    case create
    case edit(AdminBadgeItem)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let b): return "edit-\(b.id)"
        }
    }
}

struct PlatformBadgesView: View {
    @State private var items: [AdminBadgeItem] = []
    @State private var unassigned = 0
    @State private var errorText: String?
    @State private var editorMode: BadgeEditorMode?
    @State private var deleteTarget: AdminBadgeItem?
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                pageHeader(title: "铭牌", subtitle: unassigned > 0 ? "未佩戴 \(unassigned) 人" : "管理铭牌类型")

                HStack {
                    Spacer()
                    Button {
                        editorMode = .create
                    } label: {
                        Label("新建", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(PlatformStyle.blackCTA, in: Capsule())
                    }
                    .buttonStyle(PlatformPressStyle())
                }
                .padding(.horizontal, 20)

                ForEach(items) { b in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(UserBadgeChip.color(from: b.color) ?? PlatformStyle.accentBlue)
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(b.label)
                                        .font(.system(size: 16, weight: .bold))
                                    UserBadgeChip(key: b.key, label: b.label, colorName: b.color, size: .compact)
                                }
                                Text("\(b.key) · \(b.userCount ?? 0) 人 · \(b.isActive == false ? "停用" : "启用")")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PlatformStyle.textSecondary)
                                if let d = b.description, !d.isEmpty {
                                    Text(d)
                                        .font(.caption)
                                        .foregroundStyle(PlatformStyle.textTertiary)
                                }
                            }
                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 10) {
                            Button {
                                editorMode = .edit(b)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(PlatformStyle.cardMuted, in: Capsule())
                            }
                            .buttonStyle(PlatformPressStyle())

                            Button {
                                Task { await toggleActive(b) }
                            } label: {
                                Text(b.isActive == false ? "启用" : "停用")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(PlatformStyle.cardMuted, in: Capsule())
                            }
                            .buttonStyle(PlatformPressStyle())

                            Button(role: .destructive) {
                                deleteTarget = b
                            } label: {
                                Label("删除", systemImage: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.red.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(PlatformPressStyle())
                        }
                    }
                    .platformCard()
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)
        }
        .background(PlatformStyle.canvas)
        .navigationBarHidden(true)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editorMode) { mode in
            BadgeEditorSheet(mode: mode) {
                editorMode = nil
                Task { await load() }
            } onCancel: {
                editorMode = nil
            }
        }
        .alert(
            "删除铭牌？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )
        ) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) {
                if let b = deleteTarget {
                    Task { await deleteBadge(b) }
                }
            }
        } message: {
            if let b = deleteTarget {
                Text("将删除「\(b.label)」并清除所有已佩戴该铭牌的用户（约 \(b.userCount ?? 0) 人）。此操作不可撤销。")
            }
        }
        .alert("提示", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("确定", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func load() async {
        do {
            let res: AdminBadgeListResponse = try await APIClient.shared.get(APIEndpoints.adminBadges)
            items = res.items
            unassigned = res.unassignedCount ?? 0
        } catch {
            errorText = error.localizedDescription
            message = error.localizedDescription
        }
    }

    private func toggleActive(_ b: AdminBadgeItem) async {
        do {
            let _: AdminBadgeItem = try await APIClient.shared.patch(
                APIEndpoints.adminBadge(id: b.id),
                body: AdminBadgeUpdateBody(isActive: !(b.isActive ?? true))
            )
            await load()
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteBadge(_ b: AdminBadgeItem) async {
        do {
            try await APIClient.shared.delete(APIEndpoints.adminBadge(id: b.id))
            deleteTarget = nil
            await load()
            message = "已删除「\(b.label)」"
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - Badge create / edit sheet

private struct BadgeEditorSheet: View {
    let mode: BadgeEditorMode
    var onSaved: () -> Void
    var onCancel: () -> Void

    @State private var label = ""
    @State private var key = ""
    @State private var descriptionText = ""
    @State private var hexText = "#3D8BFF"
    @State private var pickerColor = Color(red: 0.24, green: 0.55, blue: 1.0)
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var suppressPickerSync = false

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editingBadge: AdminBadgeItem? {
        if case .edit(let b) = mode { return b }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fieldBlock(title: "名称", required: true) {
                        TextField("如：创始人、内测官", text: $label)
                            .padding(12)
                            .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    fieldBlock(title: "Key", required: false) {
                        if isEdit {
                            Text(editingBadge?.key ?? "—")
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundStyle(PlatformStyle.textSecondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text("创建后不可修改 key。")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PlatformStyle.textTertiary)
                        } else {
                            TextField("如 founder、beta（可选，小写英文/数字/下划线）", text: $key)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text("留空则按名称自动生成。")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PlatformStyle.textTertiary)
                        }
                    }

                    fieldBlock(title: "颜色", required: true) {
                        HStack(spacing: 14) {
                            ColorPicker("", selection: $pickerColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 44, height: 44)
                                .onChange(of: pickerColor) { _, newValue in
                                    guard !suppressPickerSync else { return }
                                    if let hex = newValue.toHexRGB() {
                                        hexText = hex
                                    }
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Hex")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PlatformStyle.textTertiary)
                                TextField("#RRGGBB", text: $hexText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .padding(10)
                                    .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .onChange(of: hexText) { _, newValue in
                                        if let c = UserBadgeChip.color(from: normalizedHex(newValue)) {
                                            suppressPickerSync = true
                                            pickerColor = c
                                            suppressPickerSync = false
                                        }
                                    }
                            }
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(UserBadgeChip.color(from: normalizedHex(hexText)) ?? pickerColor)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(PlatformStyle.hairline, lineWidth: 1)
                                )
                        }
                        Text("可用系统色盘，或直接输入 #FF5500 这类色值。")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PlatformStyle.textTertiary)
                    }

                    fieldBlock(title: "说明（可选）", required: false) {
                        TextField("给运营看的备注", text: $descriptionText, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("预览")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PlatformStyle.textSecondary)
                        HStack {
                            Text(label.isEmpty ? "铭牌名称" : label)
                                .font(.system(size: 16, weight: .bold))
                            UserBadgeChip(
                                key: previewKey,
                                label: label.isEmpty ? "预览" : label,
                                colorName: normalizedHex(hexText),
                                size: .regular
                            )
                            Spacer()
                        }
                        .platformSoftCard()
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }

                    blackCapsuleButton(isSaving ? "保存中…" : (isEdit ? "保存修改" : "创建铭牌")) {
                        Task { await save() }
                    }
                    .disabled(isSaving || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
            .background(PlatformStyle.canvas)
            .navigationTitle(isEdit ? "编辑铭牌" : "新建铭牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
            }
            .onAppear { seedForm() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var previewKey: String {
        if let b = editingBadge { return b.key }
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return k.isEmpty ? "preview" : k
    }

    private func seedForm() {
        switch mode {
        case .create:
            label = ""
            key = ""
            descriptionText = ""
            hexText = "#3D8BFF"
            pickerColor = UserBadgeChip.color(from: hexText) ?? .blue
        case .edit(let b):
            label = b.label
            key = b.key
            descriptionText = b.description ?? ""
            let raw = (b.color ?? "blue").trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.hasPrefix("#") || raw.range(of: #"^[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil {
                hexText = normalizedHex(raw)
            } else if let c = UserBadgeChip.color(from: raw), let hex = c.toHexRGB() {
                hexText = hex
            } else {
                hexText = "#3D8BFF"
            }
            pickerColor = UserBadgeChip.color(from: hexText) ?? .blue
        }
    }

    private func fieldBlock<Content: View>(
        title: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PlatformStyle.textSecondary)
                if required {
                    Text("*")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.7))
                }
            }
            content()
        }
    }

    private func normalizedHex(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.hasPrefix("#") { t.removeFirst() }
        if t.count == 3 {
            t = t.map { "\($0)\($0)" }.joined()
        }
        if t.count == 6 { return "#\(t)" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorText = "请填写名称"
            return
        }
        let hex = normalizedHex(hexText)
        guard hex.hasPrefix("#"), hex.count == 7,
              hex.dropFirst().range(of: #"^[0-9A-F]{6}$"#, options: .regularExpression) != nil else {
            errorText = "颜色请使用 #RRGGBB 格式，例如 #FF5500"
            return
        }

        isSaving = true
        defer { isSaving = false }
        errorText = nil

        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch mode {
            case .create:
                let keyRaw = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !keyRaw.isEmpty {
                    let ok = keyRaw.range(of: #"^[a-z][a-z0-9_]{1,30}$"#, options: .regularExpression) != nil
                    guard ok else {
                        errorText = "Key 需为 2–31 位小写英文/数字/下划线，且以字母开头"
                        return
                    }
                }
                let _: AdminBadgeItem = try await APIClient.shared.post(
                    APIEndpoints.adminBadges,
                    body: AdminBadgeCreateBody(
                        label: name,
                        description: desc.isEmpty ? nil : desc,
                        color: hex,
                        key: keyRaw.isEmpty ? nil : keyRaw
                    )
                )
            case .edit(let b):
                let _: AdminBadgeItem = try await APIClient.shared.patch(
                    APIEndpoints.adminBadge(id: b.id),
                    body: AdminBadgeUpdateBody(
                        label: name,
                        description: desc.isEmpty ? nil : desc,
                        color: hex
                    )
                )
            }
            onSaved()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private extension Color {
    /// Best-effort sRGB hex for ColorPicker → text field sync.
    func toHexRGB() -> String? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255))
        )
        #else
        return nil
        #endif
    }
}

// MARK: - Audit

struct PlatformAuditView: View {
    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var sourceFilter: String? = nil
    @State private var items: [AuditEventItem] = []
    @State private var total = 0
    @State private var summaryTop: [(String, Int)] = []
    @State private var isLoading = false
    @State private var errorText: String?

    private let sourceOptions: [(String?, String)] = [
        (nil, "全部"),
        ("ios", "iOS"),
        ("console", "控制台"),
        ("web", "Web"),
        ("api", "API"),
        ("android", "Android"),
    ]

    private static let actionLabels: [String: String] = [
        "auth.login": "登录",
        "auth.register": "注册",
        "auth.apple_login": "Apple 登录",
        "ledger.create": "创建账本",
        "ledger.join_invite": "加入账本",
        "expense.create": "记一笔",
        "expense.refund": "退款",
        "expense.delete": "删除账单",
        "expense.confirmed": "确认账单",
        "expense.rejected": "拒绝账单",
        "settlement.create": "记录转账",
        "user.deactivate": "注销账号",
        "user.deactivate_admin": "管理员注销",
        "user.password_reset_admin": "重置密码",
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
                    Task { await load() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PlatformStyle.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(PlatformStyle.cardMuted, in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(dayString)
                        .font(.system(size: 16, weight: .bold))
                    Text("北京时间")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PlatformStyle.textTertiary)
                }
                Spacer()
                Button {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
                    if tomorrow <= Calendar.current.startOfDay(for: Date()) {
                        day = tomorrow
                        Task { await load() }
                    } else {
                        day = Calendar.current.startOfDay(for: Date())
                        Task { await load() }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PlatformStyle.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(PlatformStyle.cardMuted, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Source chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sourceOptions, id: \.1) { value, title in
                        let selected = sourceFilter == value
                        Button {
                            sourceFilter = value
                            Task { await load() }
                        } label: {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? .white : PlatformStyle.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selected ? PlatformStyle.blackCTA : PlatformStyle.cardMuted,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(PlatformPressStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)

            if isLoading && items.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let errorText {
                Spacer()
                Text(errorText).foregroundStyle(PlatformStyle.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        HStack {
                            Text("共 \(total) 条")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PlatformStyle.textSecondary)
                            if let sourceFilter {
                                miniChip(sourceFilter, color: PlatformStyle.accentPurple)
                            }
                            Spacer()
                        }

                        if !summaryTop.isEmpty && sourceFilter == nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("当日 Top 操作")
                                    .font(.system(size: 13, weight: .bold))
                                ForEach(summaryTop, id: \.0) { action, count in
                                    HStack {
                                        Text(Self.actionLabels[action] ?? action)
                                            .font(.system(size: 13, weight: .medium))
                                        Spacer()
                                        Text("\(count)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                    }
                                }
                            }
                            .platformSoftCard()
                        }

                        ForEach(items) { e in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(Self.actionLabels[e.action] ?? e.action)
                                        .font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    Text(timeLabel(e.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(PlatformStyle.textTertiary)
                                }
                                Text(e.actorLabel ?? "—")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(PlatformStyle.textSecondary)
                                if let s = e.summary, !s.isEmpty {
                                    Text(s)
                                        .font(.system(size: 12))
                                        .foregroundStyle(PlatformStyle.textTertiary)
                                }
                                HStack {
                                    miniChip(e.source ?? "api", color: PlatformStyle.accentPurple)
                                    if let ip = e.ip {
                                        Text(ip)
                                            .font(.caption2)
                                            .foregroundStyle(PlatformStyle.textTertiary)
                                    }
                                }
                            }
                            .platformCard(padding: 14)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .background(PlatformStyle.canvas)
        .navigationTitle("审计日志")
        .task { await load() }
    }

    private var dayString: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: day)
    }

    private func timeLabel(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // Avoid `async let T: Decodable` (Swift 6: MainActor-isolated Decodable in nonisolated child).
        do {
            let res: AuditEventListResponse = try await APIClient.shared.get(
                APIEndpoints.adminAuditEvents(day: dayString, source: sourceFilter, limit: 200)
            )
            items = res.items
            total = res.total
            errorText = nil
        } catch {
            errorText = error.localizedDescription
            return
        }
        if let sum: AuditSummaryResponse = try? await APIClient.shared.get(
            APIEndpoints.adminAuditSummary(day: dayString)
        ) {
            summaryTop = (sum.byAction ?? [])
                .sorted { $0.count > $1.count }
                .prefix(5)
                .map { ($0.action, $0.count) }
        }
    }
}

// MARK: - Platform accounts

struct PlatformOpsAccountsView: View {
    @State private var rows: [UserResponse] = []
    @State private var showCreate = false
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var message: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                blackCapsuleButton("新建平台账号") {
                    showCreate = true
                }

                ForEach(rows) { u in
                    HStack(spacing: 12) {
                        RemoteAvatarView(
                            avatarUrl: u.avatarUrl,
                            fallbackText: u.resolvedDisplayName,
                            size: 44,
                            fallbackBackground: PlatformStyle.accentOrange,
                            fallbackForeground: .white
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(u.resolvedDisplayName)
                                .font(.system(size: 16, weight: .bold))
                            Text("@\(u.username)")
                                .font(.subheadline)
                                .foregroundStyle(PlatformStyle.textSecondary)
                            Text(u.email)
                                .font(.caption)
                                .foregroundStyle(PlatformStyle.textTertiary)
                        }
                        Spacer()
                        miniChip("平台", color: PlatformStyle.accentOrange)
                    }
                    .platformCard()
                }
            }
            .padding(20)
        }
        .background(PlatformStyle.canvas)
        .navigationTitle("平台账号")
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    TextField("邮箱", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                    TextField("显示名", text: $displayName)
                    SecureField("密码（≥8）", text: $password)
                }
                .navigationTitle("新建平台账号")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showCreate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("创建") { Task { await create() } }
                    }
                }
            }
        }
        .alert("提示", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("确定", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // list returns array of UserResponse
            rows = try await APIClient.shared.get(APIEndpoints.adminPlatformUsers)
        } catch {
            message = error.localizedDescription
        }
    }

    private func create() async {
        do {
            let _: UserResponse = try await APIClient.shared.post(
                APIEndpoints.adminPlatformUsers,
                body: PlatformUserCreateBody(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
            )
            showCreate = false
            email = ""; username = ""; password = ""; displayName = ""
            message = "已创建"
            await load()
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - Expense detail (read-only ops)

struct PlatformExpenseDetailSheet: View {
    let expense: ExpenseWithDetails
    var members: [MemberResponse] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(expense.title)
                            .font(.system(size: 22, weight: .bold))
                        Text(statusLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PlatformStyle.accentPurple)
                    }

                    HStack(spacing: 12) {
                        detailStat("金额", netAmount.formattedCurrency)
                        if let refund = expense.refundAmount, refund > 0 {
                            detailStat("退款", refund.formattedCurrency)
                        }
                        detailStat("原价", expense.totalAmount.formattedCurrency)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("信息")
                            .font(.system(size: 15, weight: .bold))
                        infoRow("付款人", expense.payer.resolvedDisplayName)
                        infoRow("分类", expense.category ?? "—")
                        if let note = expense.note, !note.isEmpty {
                            infoRow("备注", note)
                        }
                        if let date = expense.expenseDate {
                            infoRow("日期", dateLabel(date))
                        }
                    }
                    .platformCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("分摊")
                            .font(.system(size: 15, weight: .bold))
                        if expense.splits.isEmpty {
                            Text("无分摊明细")
                                .foregroundStyle(PlatformStyle.textTertiary)
                        } else {
                            ForEach(expense.splits) { split in
                                HStack {
                                    Text(nameForUserId(split.userId, memberId: split.memberId))
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Text(split.amount.formattedCurrency)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .platformCard()

                    if !expense.confirmations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("确认情况")
                                .font(.system(size: 15, weight: .bold))
                            ForEach(expense.confirmations) { c in
                                HStack {
                                    Text(nameForUserId(c.userId, memberId: nil))
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Text(confirmLabel(c.status))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PlatformStyle.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .platformSoftCard()
                    }
                }
                .padding(20)
            }
            .background(PlatformStyle.canvas)
            .navigationTitle("账单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var netAmount: Decimal {
        expense.totalAmount - (expense.refundAmount ?? 0)
    }

    private var statusLabel: String {
        switch expense.status {
        case "confirmed": return "已确认"
        case "pending": return "待确认"
        case "rejected": return "已否决"
        default: return expense.status
        }
    }

    private func confirmLabel(_ status: String) -> String {
        switch status {
        case "confirmed": return "已确认"
        case "rejected": return "已否决"
        case "pending": return "待确认"
        default: return status
        }
    }

    private func nameForUserId(_ userId: String?, memberId: String?) -> String {
        if let userId, let m = members.first(where: { $0.userId == userId }) {
            if let u = m.user {
                return u.publicDisplayName ?? u.displayName ?? u.username
            }
            return m.nickname ?? m.temporaryName ?? "用户"
        }
        if let memberId, let m = members.first(where: { $0.id == memberId }) {
            return m.temporaryName ?? m.nickname ?? "成员"
        }
        if let userId {
            return "用户 \(String(userId.prefix(8)))"
        }
        return "成员"
    }

    private func detailStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PlatformStyle.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .platformSoftCard(padding: 12)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(PlatformStyle.textSecondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PlatformStyle.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Decimal display helper

private extension Decimal {
    var formattedCurrency: String {
        let n = NSDecimalNumber(decimal: self)
        return String(format: "¥%.2f", n.doubleValue)
    }
}
