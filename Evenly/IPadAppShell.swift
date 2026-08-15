//
//  IPadAppShell.swift
//  Evenly
//
//  Exactly TWO columns: sidebar | detail.
//  Detail is a single canvas (IPadLedgerWorkspace) — no third nested pane.
//

import SwiftUI

enum IPadSidebarItem: Hashable {
    case ledgers
    case settings
}

struct IPadAppShell<Detail: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var ledgerStore: LedgerStore
    @EnvironmentObject var themeManager: ThemeManager

    @Binding var selectedSidebar: IPadSidebarItem
    var onAddLedger: () -> Void = {}
    @ViewBuilder var detailContent: () -> Detail

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .tint(EvenlyStyle.brandBlue)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            Section {
                navRow(.ledgers, title: "账本", systemImage: "book.fill")
                navRow(.settings, title: "设置", systemImage: "gearshape.fill")
            }

            if selectedSidebar == .ledgers {
                Section("账本") {
                    if ledgerStore.ledgers.isEmpty {
                        Text("还没有账本")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ledgerStore.ledgers) { ledger in
                            Button {
                                HapticManager.selectionChanged()
                                ledgerStore.setCurrentLedger(ledger)
                                selectedSidebar = .ledgers
                            } label: {
                                ledgerRow(ledger)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selectionBackground(for: ledger))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Evenly")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if selectedSidebar == .ledgers {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.impact(.medium)
                        onAddLedger()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建账本")
                }
            }
        }
    }

    private func navRow(_ item: IPadSidebarItem, title: String, systemImage: String) -> some View {
        Button {
            HapticManager.selectionChanged()
            selectedSidebar = item
        } label: {
            Label(title, systemImage: systemImage)
                .fontWeight(selectedSidebar == item ? .semibold : .regular)
                .foregroundStyle(selectedSidebar == item ? EvenlyStyle.brandBlue : .primary)
        }
    }

    private func ledgerRow(_ ledger: Ledger) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ledger.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(ledger.memberCount) 人 · \(ledger.expenseCount) 笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if ledgerStore.currentLedger?.id == ledger.id {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EvenlyStyle.brandBlue)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func selectionBackground(for ledger: Ledger) -> Color {
        guard ledgerStore.currentLedger?.id == ledger.id else { return .clear }
        return EvenlyStyle.brandBlueSoft(colorScheme).opacity(0.55)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selectedSidebar {
        case .settings:
            NavigationStack {
                SettingsView()
                    .environmentObject(auth)
                    .environmentObject(themeManager)
            }
        case .ledgers:
            detailContent()
        }
    }
}
