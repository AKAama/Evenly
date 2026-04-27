//
//  LedgerListView.swift
//  Evenly
//
//  Ledger list view with modern animations and interactions
//

import SwiftUI

struct LedgerListView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: LedgerStore
    
    @State private var searchText = ""
    @State private var selectedLedger: Ledger?
    @State private var showingDeleteAlert = false
    @State private var ledgerToDelete: Ledger?
    
    private var filteredLedgers: [Ledger] {
        if searchText.isEmpty {
            return store.ledgers
        }
        return store.ledgers.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
            ForEach(filteredLedgers) { ledger in
                NavigationLink {
                    LedgerDetailView(ledgerId: ledger.id)
                } label: {
                    ledgerRowView(ledger)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        HapticManager.notificationOccurred(.warning)
                        store.deleteLedger(ledger)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        HapticManager.impact(.medium)
                        selectedLedger = ledger
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    
                    Button {
                        HapticManager.impact(.medium)
                        UIPasteboard.general.string = ledger.title
                        HapticManager.notificationOccurred(.success)
                    } label: {
                        Label("复制名称", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        HapticManager.notificationOccurred(.warning)
                        ledgerToDelete = ledger
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .listRowAnimation()
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "搜索账本")
        .refreshable {
            HapticManager.impact(.light)
            if let uid = auth.user?.id {
                store.bind(userId: uid)
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        .confirmationDialog(
            "确认删除",
            isPresented: $showingDeleteAlert,
            message: "确定要删除账本 \"\(ledgerToDelete?.title ?? "")\" 吗？此操作无法撤销。",
            confirmTitle: "删除",
            destructive: true
        ) {
            if let ledger = ledgerToDelete {
                store.deleteLedger(ledger)
            }
        }
        .onAppear {
            HapticManager.prepare()
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
    
    private func ledgerRowView(_ ledger: Ledger) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ledger.id == store.currentLedger?.id ? 
                          Color.blue : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .scaleOnPress()
                
                Text(String(ledger.title.prefix(1)))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ledger.id == store.currentLedger?.id ? .white : .primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ledger.title)
                    .font(.headline)
                    .lineLimit(1)
                    .dynamicTypeSize(.accessibility2)
                
                HStack(spacing: 8) {
                    Label("\(ledger.participants.count)", systemImage: "person.2")
                    if !ledger.expenses.isEmpty {
                        Label("\(ledger.expenses.count)", systemImage: "list.bullet")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}


#Preview {
    NavigationStack {
        LedgerListView()
            .environmentObject(AuthManager())
            .environmentObject(LedgerStore())
    }
}
