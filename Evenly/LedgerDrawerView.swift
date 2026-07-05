//
//  LedgerDrawerView.swift
//  Evenly
//
//  Created by alex_yehui on 2025/12/14.
//  Modern drawer view with animations and haptics
//

import SwiftUI

struct LedgerDrawerView: View {
    @EnvironmentObject var ledgerStore: LedgerStore
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var ledgerToDelete: Ledger?
    
    let showingAddLedger: () -> Void
    
    private var filteredLedgers: [Ledger] {
        if searchText.isEmpty {
            return ledgerStore.ledgers
        }
        return ledgerStore.ledgers.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    userHeaderView
                }

                Section {
                    if ledgerStore.ledgers.isEmpty {
                        HStack {
                            Spacer()
                            Text("暂无账本")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else if filteredLedgers.isEmpty {
                        HStack {
                            Spacer()
                            Text("未找到匹配的账本")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(filteredLedgers) { ledger in
                            ledgerRowView(ledger)
                                .listRowAnimation()
                        }
                    }
                } header: {
                    Text("我的账本")
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "搜索账本")
            .navigationTitle("账本列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.impact(.medium)
                        showingAddLedger()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.spring(.light))
                }
            }
            .confirmationDialog(
                "确认删除",
                isPresented: $showingDeleteConfirmation,
                message: "确定要删除账本 \"\(ledgerToDelete?.title ?? "")\" 吗？",
                confirmTitle: "删除",
                destructive: true
            ) {
                if let ledger = ledgerToDelete {
                    ledgerStore.deleteLedger(ledger)
                }
            }
        }
    }

    private var userHeaderView: some View {
        HStack(spacing: 12) {
            RemoteAvatarView(
                avatarUrl: auth.userProfile?.avatarUrl,
                localImage: auth.avatarImage,
                fallbackText: auth.userProfile?.displayName ?? "用户",
                size: 50
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(auth.userProfile?.displayName ?? "用户")
                    .font(.headline)
                    .dynamicTypeSize(.accessibility2)
                if let username = auth.userProfile?.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func ledgerRowView(_ ledger: Ledger) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ledger.title)
                        .font(.headline)
                        .dynamicTypeSize(.accessibility2)
                    if ledgerStore.currentLedger?.id == ledger.id {
                        Text("当前")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text("\(ledger.memberCount) 人")
                    Text("•")
                    Text("\(ledger.expenseCount) 笔")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if ledgerStore.currentLedger?.id == ledger.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.impact(.light)
            ledgerStore.setCurrentLedger(ledger)
            dismiss()
        }
        .swipeActions(edge: .trailing) {
            if ledger.ownerId == auth.user?.id {
                Button(role: .destructive) {
                    HapticManager.notificationOccurred(.warning)
                    ledgerStore.deleteLedger(ledger)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            Button {
                HapticManager.impact(.medium)
                ledgerStore.setCurrentLedger(ledger)
            } label: {
                Label("设为当前", systemImage: "checkmark.circle")
            }
            
            if ledger.ownerId == auth.user?.id {
                Button(role: .destructive) {
                    HapticManager.notificationOccurred(.warning)
                    ledgerToDelete = ledger
                    showingDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LedgerDrawerView(
        showingAddLedger: {}
    )
    .environmentObject(LedgerStore())
}
