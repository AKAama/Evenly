import SwiftUI

struct LedgerMembersView: View {
    let ledger: Ledger

    var body: some View {
        List(ledger.participants.filter { !$0.isRemoved }) { participant in
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    RemoteAvatarView(
                        avatarUrl: memberRecord(for: participant)?.user?.avatarUrl,
                        fallbackText: participant.name,
                        size: 42
                    )
                    .opacity((participant.isPending || participant.isRejected) ? 0.55 : 1.0)

                    if participant.userId == ledger.ownerId {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(3)
                            .background(Circle().fill(Color(.systemBackground)))
                            .overlay(Circle().stroke(Color.orange.opacity(0.35), lineWidth: 0.8))
                            .offset(x: 4, y: -4)
                            .accessibilityLabel("账本创建者")
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(participant.name)
                            .font(.body)
                            .foregroundStyle((participant.isPending || participant.isRejected) ? .secondary : .primary)
                        if let user = memberRecord(for: participant)?.user {
                            UserBadgeChip(key: user.badge, label: user.badgeLabel, colorName: user.badgeColor)
                        }
                        if participant.isPending {
                            Text("邀请中")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        } else if participant.isRejected {
                            Text("已拒绝")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(roleText(for: participant))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 3)
        }
        .navigationTitle("账本成员")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func memberRecord(for participant: Person) -> MemberResponse? {
        ledger.members?.first {
            $0.id == participant.id.uuidString
                || (participant.userId != nil && $0.userId == participant.userId)
        }
    }

    private func roleText(for participant: Person) -> String {
        if participant.userId == ledger.ownerId { return "账本创建者" }
        if participant.isPending { return "等待对方接受邀请" }
        if participant.isRejected { return "对方已拒绝邀请" }
        return participant.isTemporary ? "临时成员" : "成员"
    }
}

struct ExpenseDetailView: View {
    let expense: Expense
    let ledger: Ledger
    var currentUserId: String? = nil
    var onEdit: (() -> Void)? = nil
    var onChangeConfirmation: ((Expense, ConfirmationStatus) async -> Result<Expense, Error>)? = nil
    var onSetRefund: ((Decimal, String?) async -> Result<Expense, Error>)? = nil

    @State private var isChangingConfirmation = false
    @State private var confirmationError: String?
    @ScaledMetric(relativeTo: .caption) private var confirmationColumnWidth: CGFloat = 96
    @ScaledMetric(relativeTo: .caption) private var confirmationIconWidth: CGFloat = 16
    @State private var showRefundSheet = false
    @State private var refundText = ""
    @State private var refundNote = ""
    @State private var isSavingRefund = false
    @State private var refundError: String?
    @State private var displayedExpense: Expense?

    private var current: Expense { displayedExpense ?? expense }

    private var canEdit: Bool {
        guard current.createdBy == currentUserId else { return false }
        if current.status == .rejected { return false }
        // When the ledger skips confirmation, creators may still edit confirmed bills.
        if !ledger.requireConfirmation { return true }
        return current.status == .pending
    }

    private var canRefund: Bool {
        current.status != .rejected
            && onSetRefund != nil
            && (current.createdBy == currentUserId || current.payer.userId == currentUserId)
    }

    private var canChangeConfirmation: Bool {
        guard let currentUserId else { return false }
        let response = current.confirmations[currentUserId]
        return ledger.requireConfirmation
            && onChangeConfirmation != nil
            && (response == .confirmed || response == .rejected)
            && current.createdBy != currentUserId
            && current.payer.userId != currentUserId
            && current.participants.contains { $0.userId == currentUserId }
    }

    var body: some View {
        List {
            Section {
                ExpenseDetailHeader(expense: current)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if let note = current.note, !note.isEmpty {
                Section("备注") {
                    Text(note)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            if let urls = current.receiptURLs, !urls.isEmpty {
                Section("凭据（\(urls.count)）") {
                    ExpenseReceiptGallery(urls: urls, expenseId: current.id)
                }
            }

            Section("参与成员") {
                ForEach(current.participants) { participant in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            RemoteAvatarView(
                                avatarUrl: memberRecord(for: participant)?.user?.avatarUrl,
                                fallbackText: participant.name,
                                size: 36
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.name)
                                    .font(.body)
                                if participant.userId == current.payer.userId {
                                    Text("付款人")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if ledger.requireConfirmation {
                                confirmationLabel(for: participant)
                            }
                        }
                        if participant.userId == currentUserId, let confirmationError {
                            Text(confirmationError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        if participant.id != current.participants.last?.id {
                            Divider().padding(.leading, 48)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }

            if canRefund || canEdit {
                Section {
                    if canRefund {
                        Button {
                            refundText = current.refundAmount > 0
                                ? NSDecimalNumber(decimal: current.refundAmount).stringValue
                                : ""
                            refundNote = ""
                            refundError = nil
                            showRefundSheet = true
                            HapticManager.impact(.light)
                        } label: {
                            Label(
                                current.hasRefund ? "修改退款" : "记录退款",
                                systemImage: "arrow.uturn.backward.circle"
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if canEdit {
                        Button {
                            HapticManager.impact(.medium)
                            onEdit?()
                        } label: {
                            Label("编辑账单", systemImage: "pencil")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } footer: {
                    Text("退款会冲减这笔支出（例如住宿 600、退 100 → 实付 500），原价保留。创建者或付款人可记录。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .interactiveDismissDisabled(isChangingConfirmation)
        .navigationTitle("账单详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑") {
                        HapticManager.impact(.medium)
                        onEdit?()
                    }
                }
            }
        }
        .sheet(isPresented: $showRefundSheet) {
            NavigationStack {
                Form {
                    Section {
                        HStack {
                            Text("原价")
                            Spacer()
                            Text(ExpenseChrome.money(current.amount))
                                .foregroundStyle(.secondary)
                        }
                        TextField("退款金额", text: $refundText)
                            .keyboardType(.decimalPad)
                        if let amount = Decimal(string: refundText), amount > 0, amount < current.amount {
                            HStack {
                                Text("实付")
                                Spacer()
                                Text(ExpenseChrome.money(current.amount - amount))
                                    .fontWeight(.semibold)
                            }
                        }
                    } footer: {
                        Text("退款须小于原价。填 0 可清除退款。")
                    }
                    Section("说明（可选）") {
                        TextField("例如：房型变更退款", text: $refundNote)
                    }
                    if let refundError {
                        Section {
                            Text(refundError)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    }
                }
                .navigationTitle(current.hasRefund ? "修改退款" : "记录退款")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showRefundSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            saveRefund()
                        }
                        .disabled(isSavingRefund || Decimal(string: refundText) == nil)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear { displayedExpense = expense }
    }

    private func saveRefund() {
        guard let amount = Decimal(string: refundText), amount >= 0, amount < current.amount else {
            refundError = "请输入小于原价的退款金额"
            return
        }
        guard let onSetRefund else { return }
        isSavingRefund = true
        refundError = nil
        Task {
            let note = refundNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = await onSetRefund(amount, note.isEmpty ? nil : note)
            await MainActor.run {
                isSavingRefund = false
                switch result {
                case .success(let updated):
                    displayedExpense = updated
                    showRefundSheet = false
                    HapticManager.notificationOccurred(.success)
                case .failure(let error):
                    refundError = error.localizedDescription
                    HapticManager.notificationOccurred(.error)
                }
            }
        }
    }

    @MainActor
    private func changeConfirmation(to status: ConfirmationStatus) async {
        guard canChangeConfirmation, !isChangingConfirmation,
              let currentUserId, current.confirmations[currentUserId] != status,
              status == .confirmed || status == .rejected,
              let onChangeConfirmation else { return }
        isChangingConfirmation = true
        confirmationError = nil
        defer { isChangingConfirmation = false }
        switch await onChangeConfirmation(current, status) {
        case .success(let updated):
            displayedExpense = updated
            HapticManager.notificationOccurred(.success)
        case .failure(let error):
            confirmationError = error.localizedDescription
            HapticManager.notificationOccurred(.error)
        }
    }

    private func memberRecord(for participant: Person) -> MemberResponse? {
        ledger.members?.first {
            $0.id == participant.id.uuidString
                || (participant.userId != nil && $0.userId == participant.userId)
        }
    }

    @ViewBuilder
    private func confirmationLabel(for participant: Person) -> some View {
        if participant.userId == currentUserId && canChangeConfirmation {
            Menu {
                if current.confirmationStatus(for: participant) == .confirmed {
                    Button("改为拒绝", systemImage: "xmark.circle", role: .destructive) {
                        Task { await changeConfirmation(to: .rejected) }
                    }
                } else {
                    Button("改为确认", systemImage: "checkmark.circle") {
                        Task { await changeConfirmation(to: .confirmed) }
                    }
                }
            } label: {
                confirmationStatusContent(for: participant, isInteractive: true)
            }
            .buttonStyle(.plain)
            .disabled(isChangingConfirmation)
            .accessibilityLabel("你的状态：\(confirmationPresentation(for: participant).text)")
            .accessibilityHint("点开可修改你自己的确认或拒绝决定")
        } else {
            confirmationStatusContent(for: participant, isInteractive: false)
        }
    }

    private func confirmationPresentation(for participant: Person) -> (text: String, icon: String, color: Color) {
        if participant.userId == current.createdBy || participant.userId == current.payer.userId || participant.isTemporary {
            return ("无需确认", "checkmark.circle.fill", .green)
        }
        switch current.confirmationStatus(for: participant) {
        case .confirmed: return ("已确认", "checkmark.circle.fill", .green)
        case .rejected: return ("已拒绝", "xmark.circle.fill", .red)
        case .pending: return ("待确认", "clock", .secondary)
        }
    }

    private func confirmationStatusContent(for participant: Person, isInteractive: Bool) -> some View {
        let presentation = confirmationPresentation(for: participant)
        return HStack(spacing: 6) {
            Group {
                if isInteractive && isChangingConfirmation {
                    ProgressView().controlSize(.mini).tint(presentation.color)
                } else {
                    Image(systemName: presentation.icon)
                }
            }
            .frame(width: confirmationIconWidth)
            Text(presentation.text).lineLimit(1)
            Spacer(minLength: 0)
            if isInteractive {
                Image(systemName: "chevron.down").font(.caption2)
            }
        }
        .font(.caption)
        .foregroundStyle(presentation.color)
        .frame(width: confirmationColumnWidth, alignment: .leading)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
