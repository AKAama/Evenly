//
//  SettlementDetailView.swift
//  Evenly
//
//  分账明细:每人的余额 + 全部转账方案
//

import SwiftUI

struct SettlementDetailView: View {
    let ledger: Ledger
    let balanceResults: [BalanceResult]
    let suggestions: [Settlement]
    let actionIds: Set<String>
    var onRecordSettlement: (Settlement) -> Void

    var body: some View {
        List {
            Section {
                if balanceResults.isEmpty {
                    Text("暂无参与者")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(balanceResults) { result in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(result.isPositive ? Color.green.opacity(0.2) : (result.balance < 0 ? Color.red.opacity(0.2) : Color.gray.opacity(0.2)))
                                    .frame(width: 36, height: 36)
                                Text(String(result.person.name.prefix(1)))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(result.isPositive ? .green : (result.balance < 0 ? .red : .primary))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.person.name)
                                    .font(.subheadline)
                                Text(result.displayText)
                                    .font(.caption)
                            }

                            Spacer()

                            Text(formatAmount(result.balance))
                                .font(.headline)
                                .foregroundStyle(result.isPositive ? .green : (result.balance < 0 ? .red : .secondary))
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("分账结果")
            } footer: {
                Text("正数表示应收，负数表示应付")
            }

            Section {
                if suggestions.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("账目已结清")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(suggestions) { settlement in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(settlement.fromUserName)
                                    .font(.subheadline)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(settlement.toUserName)
                                    .font(.subheadline)
                            }
                            .frame(width: 80)

                            Spacer()

                            Text(formatAmount(settlement.amount))
                                .font(.headline)
                                .foregroundStyle(.orange)

                            Button {
                                onRecordSettlement(settlement)
                            } label: {
                                if actionIds.contains(settlement.id) {
                                    ProgressView()
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(actionIds.contains(settlement.id))
                        }
                    }
                }
            } header: {
                Text("结算方案")
            } footer: {
                Text("所有人之间的转账方案，点击右侧标记已结")
            }
        }
        .navigationTitle("分账明细")
        .navigationBarTitleDisplayMode(.inline)
    }
}
