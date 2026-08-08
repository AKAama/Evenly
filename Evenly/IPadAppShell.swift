//
//  IPadAppShell.swift
//  Evenly
//
//  iPad-only shell for signed-in app users. Phone keeps TabView.
//
//  NavigationSplitView
//    sidebar → 账本列表 / 设置
//    detail  → wide ledger workspace or Settings
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
                .navigationSplitViewColumnWidth(
                    min: 260,
                    ideal: EvenlyDeviceLayout.sidebarIdealWidth,
                    max: 380
                )
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .tint(EvenlyStyle.brandBlue)
    }

    // MARK: - Sidebar (system list style — Apple HIG)

    private var sidebar: some View {
        List {
            Section {
                sidebarRow(.ledgers, title: "账本", systemImage: "book.fill")
                sidebarRow(.settings, title: "设置", systemImage: "gearshape.fill")
            }

            if selectedSidebar == .ledgers {
                Section {
                    if ledgerStore.ledgers.isEmpty {
                        Text("还没有账本")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(ledgerStore.ledgers) { ledger in
                            Button {
                                HapticManager.selectionChanged()
                                ledgerStore.setCurrentLedger(ledger)
                                selectedSidebar = .ledgers
                            } label: {
                                ledgerSidebarRow(ledger)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                ledgerStore.currentLedger?.id == ledger.id
                                    ? EvenlyStyle.brandBlueSoft(colorScheme).opacity(0.65)
                                    : Color.clear
                            )
                        }
                    }
                } header: {
                    Text("我的账本")
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

    private func ledgerSidebarRow(_ ledger: Ledger) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(EvenlyStyle.brandBlue.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(EvenlyStyle.brandBlue)
                }

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
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EvenlyStyle.brandBlue)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func sidebarRow(_ item: IPadSidebarItem, title: String, systemImage: String) -> some View {
        Button {
            HapticManager.selectionChanged()
            selectedSidebar = item
        } label: {
            Label(title, systemImage: systemImage)
                .fontWeight(selectedSidebar == item ? .semibold : .regular)
                .foregroundStyle(selectedSidebar == item ? EvenlyStyle.brandBlue : .primary)
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
            detailContent()
        }
    }
}
