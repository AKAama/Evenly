//
//  ExpenseChrome.swift
//  Evenly
//
//  Shared presentation for expense list / detail / edit — one visual language.
//

import SwiftUI

// MARK: - Formatting helpers

enum ExpenseChrome {
    static func money(_ amount: Decimal, kind: ExpenseKind = .expense) -> String {
        let n = NSDecimalNumber(decimal: amount).stringValue
        return kind.isIncome ? "+¥\(n)" : "¥\(n)"
    }

    static func netMoney(_ net: Decimal) -> String {
        let n = NSDecimalNumber(decimal: abs(net) as Decimal).stringValue
        return net >= 0 ? "+¥\(n)" : "-¥\(n)"
    }

    static func roleLabel(for kind: ExpenseKind) -> String {
        kind.isIncome ? "收款人" : "付款人"
    }

    static func peopleLabel(count: Int, kind: ExpenseKind) -> String {
        if count <= 1 { return "1 人" }
        return kind.isIncome ? "\(count) 人分配" : "\(count) 人分摊"
    }

    static func statusText(_ status: ExpenseStatus) -> String {
        switch status {
        case .pending: return "待确认"
        case .confirmed: return "已确认"
        case .rejected: return "已拒绝"
        }
    }

    static func accent(for kind: ExpenseKind) -> Color {
        kind.isIncome ? .green : EvenlyStyle.brandBlue
    }

    static func amountColor(for kind: ExpenseKind) -> Color {
        kind.isIncome ? .green : .primary
    }

    /// Prefer expense leg for icon when a pair is shown.
    static func iconSource(expense: Expense, peer: Expense?) -> Expense {
        if let peer {
            if expense.kind == .expense { return expense }
            if peer.kind == .expense { return peer }
        }
        return expense
    }
}

// MARK: - Chips

struct ExpenseKindChip: View {
    let kind: ExpenseKind

    var body: some View {
        Text(kind.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(ExpenseChrome.accent(for: kind))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(ExpenseChrome.accent(for: kind).opacity(0.12), in: Capsule())
    }
}

struct ExpenseStatusChip: View {
    let status: ExpenseStatus

    private var color: Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .green
        case .rejected: return .red
        }
    }

    var body: some View {
        Text(ExpenseChrome.statusText(status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Icon bubble

struct ExpenseIconBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    let expense: Expense
    var size: CGFloat = 40

    var body: some View {
        let accent = ExpenseChrome.accent(for: expense.kind)
        ZStack {
            Circle()
                .fill(accent.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .frame(width: size, height: size)
            if let icon = expense.icon {
                if icon.type == .emoji {
                    Text(icon.value).font(.system(size: size * 0.42))
                } else {
                    Image(systemName: icon.value)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(accent)
                }
            } else {
                Image(systemName: expense.kind.isIncome ? "arrow.down.circle.fill" : "yensign.circle.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - List row (single or linked pair)

struct ExpenseUnifiedListRow: View {
    let expense: Expense
    /// Other leg of a cost+income pair (same group_id).
    var linkedPeer: Expense? = nil

    private var displayStatus: ExpenseStatus {
        if let peer = linkedPeer {
            let statuses = [expense.status, peer.status]
            if statuses.contains(.pending) { return .pending }
            if statuses.contains(.rejected) { return .rejected }
            return .confirmed
        }
        return expense.status
    }

    private var cost: Expense? {
        if let peer = linkedPeer {
            return expense.kind == .expense ? expense : peer
        }
        return expense.kind == .expense ? expense : nil
    }

    private var income: Expense? {
        if let peer = linkedPeer {
            return expense.kind == .income ? expense : peer
        }
        return expense.kind == .income ? expense : nil
    }

    var body: some View {
        HStack(spacing: 12) {
            ExpenseIconBubble(expense: ExpenseChrome.iconSource(expense: expense, peer: linkedPeer))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(expense.title)
                        .font(.headline)
                        .lineLimit(1)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    if linkedPeer == nil {
                        ExpenseKindChip(kind: expense.kind)
                    }
                }

                if let c = cost, let i = income, linkedPeer != nil {
                    Text("支出 \(ExpenseChrome.money(c.amount)) · 收入 \(ExpenseChrome.money(i.amount, kind: .income))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    metaLine(for: c)
                } else {
                    metaLine(for: expense)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let c = cost, let i = income, linkedPeer != nil {
                    Text(ExpenseChrome.netMoney(i.amount - c.amount))
                        .font(.headline)
                        .foregroundStyle((i.amount - c.amount) >= 0 ? Color.green : Color.primary)
                } else {
                    Text(ExpenseChrome.money(expense.amount, kind: expense.kind))
                        .font(.headline)
                        .foregroundStyle(ExpenseChrome.amountColor(for: expense.kind))
                }
                ExpenseStatusChip(status: displayStatus)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metaLine(for expense: Expense) -> some View {
        HStack(spacing: 8) {
            Label(
                expense.payer.name,
                systemImage: expense.kind.isIncome ? "arrow.down.circle" : "person"
            )
            if !expense.participants.isEmpty {
                Label(
                    ExpenseChrome.peopleLabel(count: expense.participants.count, kind: expense.kind),
                    systemImage: "person.2"
                )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

// MARK: - Detail header

struct ExpenseDetailHeader: View {
    let expense: Expense
    /// All ledger expenses — used to resolve linked cost+income peers.
    var ledgerExpenses: [Expense] = []

    private var pair: (cost: Expense, income: Expense)? {
        guard let gid = expense.groupId else { return nil }
        let group = ledgerExpenses.filter { $0.groupId == gid }
        guard let cost = group.first(where: { $0.kind == .expense }),
              let income = group.first(where: { $0.kind == .income }) else { return nil }
        return (cost, income)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ExpenseIconBubble(
                    expense: ExpenseChrome.iconSource(expense: expense, peer: pair?.cost),
                    size: 52
                )
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if pair == nil {
                            ExpenseKindChip(kind: expense.kind)
                        }
                        ExpenseStatusChip(status: headerStatus)
                    }
                    Text(expense.title)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if let pair {
                VStack(alignment: .leading, spacing: 10) {
                    amountRow(label: "支出", amount: pair.cost.amount, kind: .expense)
                    amountRow(label: "收入", amount: pair.income.amount, kind: .income)
                    Divider()
                    HStack {
                        Text("净额")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ExpenseChrome.netMoney(pair.income.amount - pair.cost.amount))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(
                                (pair.income.amount - pair.cost.amount) >= 0 ? Color.green : Color.primary
                            )
                    }
                }
            } else {
                Text(ExpenseChrome.money(expense.amount, kind: expense.kind))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ExpenseChrome.amountColor(for: expense.kind))
            }

            HStack(spacing: 16) {
                labeledMeta(
                    title: ExpenseChrome.roleLabel(for: expense.kind),
                    value: expense.payer.name
                )
                labeledMeta(
                    title: "参与",
                    value: ExpenseChrome.peopleLabel(
                        count: expense.participants.count,
                        kind: expense.kind
                    )
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var headerStatus: ExpenseStatus {
        if let pair {
            let s = [pair.cost.status, pair.income.status]
            if s.contains(.pending) { return .pending }
            if s.contains(.rejected) { return .rejected }
            return .confirmed
        }
        return expense.status
    }

    private func amountRow(label: String, amount: Decimal, kind: ExpenseKind) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(ExpenseChrome.money(amount, kind: kind))
                .font(.body.weight(.semibold))
                .foregroundStyle(ExpenseChrome.amountColor(for: kind))
        }
    }

    private func labeledMeta(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
