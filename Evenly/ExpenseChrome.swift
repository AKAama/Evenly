//
//  ExpenseChrome.swift
//  Evenly
//
//  Shared presentation for expense list / detail / edit — one visual language.
//

import SwiftUI

// MARK: - Formatting helpers

enum ExpenseChrome {
    static func money(_ amount: Decimal) -> String {
        let n = NSDecimalNumber(decimal: amount).stringValue
        return "¥\(n)"
    }

    static func peopleLabel(count: Int) -> String {
        if count <= 1 { return "1 人" }
        return "\(count) 人分摊"
    }

    static func statusText(_ status: ExpenseStatus) -> String {
        switch status {
        case .pending: return "待确认"
        case .confirmed: return "已确认"
        case .rejected: return "已拒绝"
        }
    }

    static var accent: Color { EvenlyStyle.brandBlue }
}

// MARK: - Chips

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
        let accent = ExpenseChrome.accent
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
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - List row

struct ExpenseUnifiedListRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            ExpenseIconBubble(expense: expense)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                metaLine(for: expense)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(ExpenseChrome.money(expense.netAmount))
                    .font(.headline)
                    .foregroundStyle(.primary)
                if expense.hasRefund {
                    Text("含退款")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ExpenseStatusChip(status: expense.status)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metaLine(for expense: Expense) -> some View {
        HStack(spacing: 8) {
            Label(expense.payer.name, systemImage: "person")
            if !expense.participants.isEmpty {
                Label(
                    ExpenseChrome.peopleLabel(count: expense.participants.count),
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ExpenseIconBubble(expense: expense, size: 52)
                VStack(alignment: .leading, spacing: 6) {
                    ExpenseStatusChip(status: expense.status)
                    Text(expense.title)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Text(ExpenseChrome.money(expense.netAmount))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            if expense.hasRefund {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("原价")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ExpenseChrome.money(expense.amount))
                            .font(.subheadline.weight(.medium))
                    }
                    HStack {
                        Text("退款")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("−\(ExpenseChrome.money(expense.refundAmount))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
            }

            HStack(spacing: 16) {
                labeledMeta(title: "付款人", value: expense.payer.name)
                labeledMeta(
                    title: "参与",
                    value: ExpenseChrome.peopleLabel(count: expense.participants.count)
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
