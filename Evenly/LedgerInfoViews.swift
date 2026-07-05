import SwiftUI

struct LedgerMembersView: View {
    let ledger: Ledger

    var body: some View {
        List(ledger.participants) { participant in
            HStack(spacing: 12) {
                RemoteAvatarView(
                    avatarUrl: memberRecord(for: participant)?.user?.avatarUrl,
                    fallbackText: participant.name,
                    size: 42
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.name)
                        .font(.body)
                    Text(roleText(for: participant))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if participant.userId == ledger.ownerId {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.orange)
                }
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
        if memberRecord(for: participant)?.status == "pending" { return "邀请中" }
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
