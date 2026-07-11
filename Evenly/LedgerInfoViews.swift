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

    var body: some View {
        List {
            Section {
                LabeledContent("金额", value: formattedAmount)
                LabeledContent("付款人", value: expense.payer.name)
                if let date = expense.expenseDate {
                    LabeledContent("日期", value: date.formatted(date: .abbreviated, time: .omitted))
                }
                LabeledContent("状态", value: statusText)
            }

            if let note = expense.note, !note.isEmpty {
                Section("备注") { Text(note) }
            }

            Section("参与成员") {
                ForEach(expense.participants) { participant in
                    HStack {
                        RemoteAvatarView(
                            avatarUrl: memberRecord(for: participant)?.user?.avatarUrl,
                            fallbackText: participant.name,
                            size: 36
                        )
                        Text(participant.name)
                        Spacer()
                        confirmationLabel(for: participant)
                    }
                }
            }
        }
        .navigationTitle(expense.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formattedAmount: String {
        let value = NSDecimalNumber(decimal: expense.amount)
        return "¥\(value.stringValue)"
    }

    private var statusText: String {
        switch expense.status {
        case .pending: return "待确认"
        case .confirmed: return "已确认"
        case .rejected: return "已拒绝"
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
        if participant.userId == expense.createdBy {
            Label("创建者", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            switch expense.confirmationStatus(for: participant) {
            case .confirmed:
                Label("已确认", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .rejected:
                Label("已拒绝", systemImage: "xmark.circle.fill").foregroundStyle(.red)
            case .pending:
                Text(participant.isTemporary ? "无需确认" : "待确认").foregroundStyle(.secondary)
            }
        }
    }
}
