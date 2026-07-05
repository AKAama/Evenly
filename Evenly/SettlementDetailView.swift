//
//  SettlementDetailView.swift
//  Evenly
//
//  分账明细:全部转账方案
//

import SwiftUI

struct SettlementDetailView: View {
    let ledger: Ledger
    let suggestions: [Settlement]
    let actionIds: Set<String>
    var onRecordSettlement: (Settlement) -> Void

    var body: some View {
        List {
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
                Text("全部待结算")
            } footer: {
                Text("系统根据已确认账单生成的完整转账方案，完成后点击右侧勾选")
            }
        }
        .navigationTitle("全部结算方案")
        .navigationBarTitleDisplayMode(.inline)
    }
}
