//
//  SettlementDetailView.swift
//  Evenly
//
//  分账明细:全部转账方案
//

import SwiftUI

struct SettlementDetailView: View {
    @Environment(\.colorScheme) private var colorScheme

    let ledger: Ledger
    let suggestions: [Settlement]

    private var totalAmount: Decimal {
        suggestions.reduce(.zero) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if suggestions.isEmpty {
                    settledState
                } else {
                    summary

                    LazyVStack(spacing: 12) {
                        ForEach(suggestions) { settlement in
                            settlementCard(settlement)
                        }
                    }

                    Text(suggestions.contains(where: \.includesUnconfirmed)
                         ? "按全部账单预估终局流向；灰色条目仍含未确认账单"
                         : "根据账本账单自动计算的转账方案")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("转账流向")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(EvenlyStyle.brandBlue.opacity(colorScheme == .dark ? 0.2 : 0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(EvenlyStyle.brandBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("需要完成 \(suggestions.count) 笔转账")
                    .font(.headline)

                Text(ledger.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(formatAmount(totalAmount))
                .font(.title3.weight(.semibold))
                .foregroundStyle(EvenlyStyle.brandBlue)
                .monospacedDigit()
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05), lineWidth: 0.75)
        }
    }

    private func settlementCard(_ settlement: Settlement) -> some View {
        let provisional = settlement.includesUnconfirmed
        return VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Text("转账金额")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if provisional {
                        Text("未确认")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.14), in: Capsule())
                    }
                }

                Spacer()

                Text(formatAmount(settlement.amount))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(provisional ? Color.secondary : Color.primary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                personView(
                    name: settlement.fromUserName,
                    userId: settlement.fromUserId,
                    role: "付款",
                    muted: provisional
                )

                flowIndicator(muted: provisional)

                personView(
                    name: settlement.toUserName,
                    userId: settlement.toUserId,
                    role: "收款",
                    muted: provisional
                )
            }
        }
        .padding(18)
        .background(
            (provisional ? Color(.tertiarySystemFill) : Color(.secondarySystemGroupedBackground)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.04), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 14, y: 6)
        .opacity(provisional ? 0.9 : 1)
    }

    private func personView(name: String, userId: String, role: String, muted: Bool = false) -> some View {
        let person = ledger.person(by: userId)
        let accent = muted ? Color.secondary : EvenlyStyle.brandBlue

        return VStack(spacing: 7) {
            RemoteAvatarView(
                avatarUrl: person?.avatarUrl,
                fallbackText: name,
                size: 48,
                fallbackBackground: accent.opacity(colorScheme == .dark ? 0.24 : 0.12),
                fallbackForeground: accent
            )

            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(muted ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(role)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func flowIndicator(muted: Bool = false) -> some View {
        let accent = muted ? Color.secondary : EvenlyStyle.brandBlue
        return HStack(spacing: 3) {
            Capsule()
                .fill(accent.opacity(0.22))
                .frame(width: 16, height: 2)

            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
        }
        .accessibilityHidden(true)
    }

    private var settledState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(colorScheme == .dark ? 0.18 : 0.1))
                    .frame(width: 76, height: 76)

                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 6) {
                Text("账目已结清")
                    .font(.title2.weight(.semibold))

                Text("目前没有需要完成的转账")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05), lineWidth: 0.75)
        }
    }
}
