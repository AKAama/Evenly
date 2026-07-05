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

                        }
                    }
                }
            } header: {
                Text("全部待结算")
            } footer: {
                Text("系统根据全部未拒绝账单生成完整转账方案，不受结算确认影响")
            }
        }
        .navigationTitle("全部结算方案")
        .navigationBarTitleDisplayMode(.inline)
    }
}
