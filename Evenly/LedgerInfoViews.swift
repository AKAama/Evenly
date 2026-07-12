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

    private var canEdit: Bool {
        expense.status == .pending && expense.createdBy == currentUserId
    }

    private var groupPeers: [Expense] {
        guard let gid = expense.groupId else { return [expense] }
        let peers = ledger.expenses.filter { $0.groupId == gid }
        return peers.isEmpty ? [expense] : peers
    }

    var body: some View {
        List {
            Section {
                ExpenseDetailHeader(expense: expense, ledgerExpenses: ledger.expenses)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if let note = expense.note, !note.isEmpty {
                Section("备注") {
                    Text(note)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }

            // Linked pair: show both legs with same chrome as list rows.
            if groupPeers.count > 1 {
                Section {
                    ForEach(groupPeers.sorted { lhs, rhs in
                        if lhs.kind != rhs.kind { return lhs.kind == .expense }
                        return false
                    }) { leg in
                        ExpenseUnifiedListRow(expense: leg)
                            .padding(.vertical, 2)
                    }
                } header: {
                    Text("明细")
                } footer: {
                    Text("关联记账会拆成支出与收入两笔明细，结算按两笔一起计算。")
                }
            }

            Section("参与成员") {
                ForEach(expense.participants) { participant in
                    HStack(spacing: 12) {
                        RemoteAvatarView(
                            avatarUrl: memberRecord(for: participant)?.user?.avatarUrl,
                            fallbackText: participant.name,
                            size: 36
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(participant.name)
                                .font(.body)
                            if participant.userId == expense.payer.userId {
                                Text(ExpenseChrome.roleLabel(for: expense.kind))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        confirmationLabel(for: participant)
                    }
                    .padding(.vertical, 2)
                }
            }

            if canEdit {
                Section {
                    Button {
                        HapticManager.impact(.medium)
                        onEdit?()
                    } label: {
                        Label("编辑账单", systemImage: "pencil")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } footer: {
                    Text("仅待确认账单可由创建者编辑。保存后其他人需重新确认。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(expense.kind.displayName)
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
    }

    private func memberRecord(for participant: Person) -> MemberResponse? {
        ledger.members?.first {
            $0.id == participant.id.uuidString
                || (participant.userId != nil && $0.userId == participant.userId)
        }
    }

    @ViewBuilder
    private func confirmationLabel(for participant: Person) -> some View {
        if participant.userId == expense.createdBy
            || participant.userId == expense.payer.userId {
            Label("无需确认", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            switch expense.confirmationStatus(for: participant) {
            case .confirmed:
                Label("已确认", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .rejected:
                Label("已拒绝", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .pending:
                Text(participant.isTemporary ? "无需确认" : "待确认")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
