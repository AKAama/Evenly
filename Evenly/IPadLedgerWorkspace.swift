//
//  IPadLedgerWorkspace.swift
//  Evenly
//
//  iPad detail column only (one surface).
//  Parent shell already provides the sidebar → total of TWO columns, not three.
//
//  Design goals (Apple-native, not “AI fintech”):
//  - Single scrolling canvas, readable max width
//  - System grouped list language
//  - iPad-scale type, spacing, and row chrome (not phone rows stretched)
//

import SwiftUI

struct IPadLedgerWorkspace: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var ledgerStore: LedgerStore

    let ledger: Ledger
    let expenses: [Expense]
    let settlements: [Settlement]
    let isLoadingSettlements: Bool
    let settlementError: String?
    /// 0…n-1 matching ContentView.ExpenseFilter cycle labels from parent.
    let expenseFilterLabel: String
    let respondingExpenseIds: Set<UUID>

    var onCycleFilter: () -> Void
    var onAddExpense: () -> Void
    /// Opens add-expense flow and prefers voice capture when possible.
    var onVoiceExpense: () -> Void = {}
    var onMembers: () -> Void
    var onShare: () -> Void
    var onOpenExpense: (Expense) -> Void
    var onConfirmExpense: (Expense) -> Void
    var onRejectExpense: (Expense) -> Void
    var onEditExpense: (Expense) -> Void
    var onDeleteExpense: (Expense) -> Void
    var onOpenAllSettlements: () -> Void
    var canRespond: (Expense) -> Bool
    var canEdit: (Expense) -> Bool
    var formatAmount: (Decimal) -> String

    private var totalSpend: Decimal {
        ledger.expenses.reduce(Decimal.zero) { $0 + $1.netAmount }
    }

    private var netPosition: (title: String, amount: Decimal, tone: Color) {
        guard let me = auth.user?.id else {
            return ("—", 0, .secondary)
        }
        var net: Decimal = 0
        for s in settlements {
            if s.toUserId == me { net += s.amount }
            if s.fromUserId == me { net -= s.amount }
        }
        if net > 0 { return ("别人还差你", net, .green) }
        if net < 0 { return ("你还差别人", -net, .orange) }
        return ("已结清", 0, .secondary)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerBlock
                filterBar
                expensesBlock
                settlementsBlock
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: EvenlyDeviceLayout.detailComfortMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ledger.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbar }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                HapticManager.impact(.light)
                onShare()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享")

            Button {
                HapticManager.impact(.light)
                onMembers()
            } label: {
                Image(systemName: "person.2")
            }
            .accessibilityLabel("成员")

            // Primary create: icon only — menu keeps secondary paths without wordy CTAs.
            Menu {
                Button {
                    HapticManager.impact(.medium)
                    onAddExpense()
                } label: {
                    Label("添加支出", systemImage: "yensign.circle")
                }
                Button {
                    HapticManager.impact(.medium)
                    onVoiceExpense()
                } label: {
                    Label("语音添加", systemImage: "mic.fill")
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("添加")
        }
    }

    // MARK: - Header (not a marketing hero card)

    private var headerBlock: some View {
        let net = netPosition
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("总支出")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(totalSpend))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(net.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(net.amount))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(net.tone)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                metaLabel(systemImage: "person.2", text: "\(ledger.participantCount) 人")
                metaLabel(systemImage: "list.bullet", text: "\(ledger.expenseCount) 笔")
                if ledger.requireConfirmation {
                    metaLabel(systemImage: "checkmark.seal", text: "需确认")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        // Subtle top hairline instead of heavy gradient / shadow stack
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                .frame(height: 1 / UIScreen.main.scale)
                .padding(.horizontal, 1)
        }
    }

    private func metaLabel(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    // MARK: - Filter

    private var filterBar: some View {
        HStack {
            Text("账单")
                .font(.title3.weight(.semibold))
            Spacer()
            Button {
                onCycleFilter()
                HapticManager.selectionChanged()
            } label: {
                HStack(spacing: 5) {
                    Text(expenseFilterLabel)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(EvenlyStyle.brandBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(EvenlyStyle.brandBlue.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("筛选：\(expenseFilterLabel)")
        }
    }

    // MARK: - Expenses (iPad row chrome)

    private var expensesBlock: some View {
        VStack(spacing: 0) {
            if expenses.isEmpty {
                emptyExpenses
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                    IPadExpenseRow(
                        expense: expense,
                        formatAmount: formatAmount,
                        isResponding: respondingExpenseIds.contains(expense.id),
                        showActions: canRespond(expense),
                        onOpen: { onOpenExpense(expense) },
                        onConfirm: { onConfirmExpense(expense) },
                        onReject: { onRejectExpense(expense) }
                    )
                    .contextMenu {
                        Button { onOpenExpense(expense) } label: {
                            Label("查看详情", systemImage: "info.circle")
                        }
                        if canEdit(expense) {
                            Button { onEditExpense(expense) } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                        }
                        if expense.createdBy == auth.user?.id {
                            Button(role: .destructive) { onDeleteExpense(expense) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }

                    if index < expenses.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyExpenses: some View {
        ContentUnavailableView {
            Label("暂无支出", systemImage: "tray")
        } description: {
            Text("还没有记录。用右上角 + 添加，或从这里开始。")
        } actions: {
            Button {
                HapticManager.impact(.medium)
                onAddExpense()
            } label: {
                Label("添加支出", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Settlements

    private var settlementsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("转账建议")
                    .font(.title3.weight(.semibold))
                Spacer()
                if isLoadingSettlements {
                    ProgressView().controlSize(.small)
                }
                Button("全部") {
                    HapticManager.impact(.light)
                    onOpenAllSettlements()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(EvenlyStyle.brandBlue)
            }

            VStack(spacing: 0) {
                if let settlementError, settlements.isEmpty {
                    Label(settlementError, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else if settlements.isEmpty {
                    Text(ledger.requireConfirmation
                          ? "暂无建议，或仍有账单待确认"
                          : "暂无待处理转账")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(Array(settlements.enumerated()), id: \.element.id) { index, s in
                        IPadSettlementRow(settlement: s, me: auth.user?.id, formatAmount: formatAmount)
                        if index < settlements.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(ledger.requireConfirmation
                  ? "流向按已确认与待确认账单预估；含未确认的会标为灰色。"
                  : "本账本未开启确认，记账后即进入建议流向。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - iPad-only rows (not stretched phone chrome)

private struct IPadExpenseRow: View {
    let expense: Expense
    let formatAmount: (Decimal) -> String
    let isResponding: Bool
    let showActions: Bool
    var onOpen: () -> Void
    var onConfirm: () -> Void
    var onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 14) {
                    // Larger icon plate for pad density
                    ExpenseIconBubble(expense: expense)
                        .scaleEffect(1.08)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(meta)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatAmount(expense.netAmount))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                        statusText
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showActions {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    Button(role: .destructive, action: onReject) {
                        Text("拒绝")
                            .frame(minWidth: 72)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isResponding)

                    Button(action: onConfirm) {
                        if isResponding {
                            ProgressView()
                                .frame(minWidth: 72)
                        } else {
                            Text("确认")
                                .frame(minWidth: 72)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(isResponding)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var meta: String {
        var parts: [String] = [expense.payer.name]
        if !expense.participants.isEmpty {
            parts.append("\(expense.participants.count) 人分摊")
        }
        if expense.hasRefund {
            parts.append("含退款")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var statusText: some View {
        switch expense.status {
        case .pending:
            Text("待确认")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        case .confirmed:
            Text("已确认")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        case .rejected:
            Text("已拒绝")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red.opacity(0.85))
        }
    }
}

private struct IPadSettlementRow: View {
    let settlement: Settlement
    let me: String?
    let formatAmount: (Decimal) -> String

    private var iOwe: Bool { settlement.fromUserId == me }
    private var provisional: Bool { settlement.includesUnconfirmed }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iOwe ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                .font(.title3)
                .foregroundStyle(provisional ? Color.secondary : (iOwe ? Color.orange : Color.green))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(iOwe ? "转给 \(settlement.toUserName)" : "\(settlement.fromUserName) 转给你")
                    .font(.body)
                    .foregroundStyle(provisional ? .secondary : .primary)
                if provisional {
                    Text("含未确认账单")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(formatAmount(settlement.amount))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(provisional ? Color.secondary : (iOwe ? Color.orange : Color.green))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
