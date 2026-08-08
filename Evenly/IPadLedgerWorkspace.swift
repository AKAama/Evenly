//
//  IPadLedgerWorkspace.swift
//  Evenly
//
//  Wide-canvas ledger UI for iPad only.
//  Left: system-style expense list. Right: summary + settlements.
//  Avoids phone-stacked List stretched to full width.
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
    let expenseFilterLabel: String
    let respondingExpenseIds: Set<UUID>

    var onCycleFilter: () -> Void
    var onAddExpense: () -> Void
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

    var body: some View {
        GeometryReader { geo in
            let useSplit = geo.size.width >= 700
            Group {
                if useSplit {
                    HStack(spacing: 0) {
                        expenseColumn
                            .frame(minWidth: 340, idealWidth: geo.size.width * 0.58, maxWidth: .infinity)
                        Divider()
                        summaryColumn
                            .frame(width: min(400, max(300, geo.size.width * 0.38)))
                    }
                } else {
                    // Narrow iPad slide-over / split view: stack like phone but with pad padding.
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryHeaderCard
                            expenseListEmbedded
                        }
                        .padding(20)
                        .frame(maxWidth: EvenlyDeviceLayout.detailComfortMaxWidth)
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ledger.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

            Button {
                HapticManager.impact(.medium)
                onAddExpense()
            } label: {
                Label("记一笔", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    // MARK: - Expense column

    private var expenseColumn: some View {
        List {
            Section {
                filterHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                if expenses.isEmpty {
                    emptyExpenses
                } else {
                    ForEach(expenses) { expense in
                        expenseRow(expense)
                    }
                }
            } header: {
                Text("账单（\(expenses.count)）")
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private var filterHeader: some View {
        Button {
            onCycleFilter()
            HapticManager.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Text(expenseFilterLabel)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(EvenlyStyle.brandBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func expenseRow(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ExpenseUnifiedListRow(expense: expense)

            if canRespond(expense) {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.impact(.rigid, intensity: 0.8)
                        onRejectExpense(expense)
                    } label: {
                        Label("拒绝", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(respondingExpenseIds.contains(expense.id))

                    Button {
                        HapticManager.impact(.medium, intensity: 0.9)
                        onConfirmExpense(expense)
                    } label: {
                        if respondingExpenseIds.contains(expense.id) {
                            ProgressView()
                        } else {
                            Text("确认")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(respondingExpenseIds.contains(expense.id))
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { onOpenExpense(expense) }
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
    }

    private var emptyExpenses: some View {
        ContentUnavailableView {
            Label("暂无账单", systemImage: "doc.text")
        } description: {
            Text("点右上角「记一笔」添加第一笔")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var expenseListEmbedded: some View {
        VStack(alignment: .leading, spacing: 12) {
            filterHeader
            if expenses.isEmpty {
                emptyExpenses
                    .frame(minHeight: 180)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(expenses) { expense in
                        expenseRow(expense)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        if expense.id != expenses.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: - Summary column

    private var summaryColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryHeaderCard
                settlementCard
                membersHint
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var summaryHeaderCard: some View {
        let total = ledger.expenses.reduce(Decimal.zero) { $0 + $1.netAmount }
        let mine = myNetPosition
        return VStack(alignment: .leading, spacing: 14) {
            Text("账本概览")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总支出")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(total))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(mine.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(mine.amount))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(mine.color)
                }
            }

            HStack(spacing: 12) {
                metricChip(icon: "person.2.fill", text: "\(ledger.participantCount) 成员")
                metricChip(icon: "list.bullet", text: "\(ledger.expenseCount) 笔账单")
            }

            Button {
                HapticManager.impact(.medium)
                onAddExpense()
            } label: {
                Label("记一笔", systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var settlementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("与我相关的转账")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoadingSettlements {
                    ProgressView().controlSize(.small)
                }
            }

            if let settlementError, settlements.isEmpty {
                Label(settlementError, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if settlements.isEmpty {
                Text(ledger.requireConfirmation
                      ? "暂无建议转账（或仍有未确认账单）"
                      : "账单结清或暂无流向")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(settlements) { s in
                    settlementRow(s)
                    if s.id != settlements.last?.id {
                        Divider()
                    }
                }
            }

            Button {
                HapticManager.impact(.light)
                onOpenAllSettlements()
            } label: {
                HStack {
                    Text("查看全部转账流向")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func settlementRow(_ settlement: Settlement) -> some View {
        let me = auth.user?.id
        let iOwe = settlement.fromUserId == me
        let provisional = settlement.includesUnconfirmed
        return HStack(spacing: 10) {
            Image(systemName: iOwe ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(provisional ? Color.secondary : (iOwe ? Color.orange : Color.green))
            VStack(alignment: .leading, spacing: 2) {
                Text(iOwe ? "转给 \(settlement.toUserName)" : "\(settlement.fromUserName) 转给你")
                    .font(.subheadline)
                    .foregroundStyle(provisional ? .secondary : .primary)
                if provisional {
                    Text("含未确认")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(formatAmount(settlement.amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(provisional ? Color.secondary : (iOwe ? Color.orange : Color.green))
        }
        .padding(.vertical, 4)
    }

    private var membersHint: some View {
        Button {
            HapticManager.impact(.light)
            onMembers()
        } label: {
            HStack {
                Label("成员与邀请", systemImage: "person.crop.circle.badge.plus")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline.weight(.medium))
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func metricChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }

    /// Positive = others owe me; negative = I owe others (from related settlements).
    private var myNetPosition: (label: String, amount: Decimal, color: Color) {
        guard let me = auth.user?.id else {
            return ("—", 0, .secondary)
        }
        var net: Decimal = 0
        for s in settlements {
            if s.toUserId == me { net += s.amount }
            if s.fromUserId == me { net -= s.amount }
        }
        if net > 0 {
            return ("别人还差你", net, .green)
        }
        if net < 0 {
            return ("你还差别人", -net, .orange)
        }
        return ("已结清", 0, .secondary)
    }
}
