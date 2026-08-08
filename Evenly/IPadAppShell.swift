//
//  IPadAppShell.swift
//  Evenly
//
//  iPad-first navigation for signed-in **app** users (not platform ops).
//  Phone keeps ContentView's TabView; this shell is used only when
//  `EvenlyDeviceLayout.isPadIdiom` is true.
//
//  Layout: NavigationSplitView
//    sidebar → ledgers / settings
//    detail  → current ledger detail (injected) or Settings
//

import SwiftUI

enum IPadSidebarItem: Hashable {
    case ledgers
    case settings
}

struct IPadAppShell<LedgerDetail: View>: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var ledgerStore: LedgerStore
    @EnvironmentObject var themeManager: ThemeManager

    @Binding var selectedSidebar: IPadSidebarItem
    @ViewBuilder var ledgerDetail: () -> LedgerDetail

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: 240,
                    ideal: EvenlyDeviceLayout.sidebarIdealWidth,
                    max: 360
                )
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
                sidebarRow(.ledgers, title: "账本", systemImage: "book.fill")
                sidebarRow(.settings, title: "设置", systemImage: "gearshape.fill")
            }

            if selectedSidebar == .ledgers {
                Section("我的账本") {
                    if ledgerStore.ledgers.isEmpty {
                        Text("还没有账本")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ledgerStore.ledgers) { ledger in
                            Button {
                                ledgerStore.setCurrentLedger(ledger)
                                selectedSidebar = .ledgers
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "book.closed.fill")
                                        .foregroundStyle(EvenlyStyle.brandBlue)
                                    VStack(alignment: .leading, spacing: 2) {
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
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(EvenlyStyle.brandBlue)
                                            .imageScale(.medium)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Evenly")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sidebarRow(_ item: IPadSidebarItem, title: String, systemImage: String) -> some View {
        Button {
            selectedSidebar = item
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundStyle(selectedSidebar == item ? EvenlyStyle.brandBlue : .primary)
                .fontWeight(selectedSidebar == item ? .semibold : .regular)
        }
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
            if ledgerStore.currentLedger != nil {
                ledgerDetail()
            } else {
                ContentUnavailableView {
                    Label("选择一本账本", systemImage: "books.vertical")
                } description: {
                    Text("从左侧列表打开账本，或新建一本开始记账。")
                }
            }
        }
    }
}
