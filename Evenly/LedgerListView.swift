//
//  LedgerListView.swift
//  Evenly
//
//  Ledger list view
//

import SwiftUI

struct LedgerListView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: LedgerStore

    var body: some View {
        List(store.ledgers) { ledger in
            NavigationLink {
                LedgerDetailView(ledgerId: ledger.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ledger.title)
                        .font(.headline)
                    Text("\(ledger.participants.count) 位参与者")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    store.deleteLedger(ledger)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .onAppear {
            if let uid = auth.user?.id {
                store.bind(userId: uid)
            }
        }
        .onChange(of: auth.user?.id) { _, newValue in
            if let uid = newValue {
                store.bind(userId: uid)
            } else {
                store.stop()
            }
        }
    }
}


#Preview {
    NavigationStack {
        LedgerListView()
            .environmentObject(AuthManager())
            .environmentObject(LedgerStore())
    }
}
