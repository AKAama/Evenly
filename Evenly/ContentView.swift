//
//  ContentView.swift
//  Evenly
//
//  Main content view with tab navigation and modern design
//

import SwiftUI

struct ContentView: View {
    @StateObject var auth = AuthManager()
    @StateObject var ledgerStore = LedgerStore()
    @StateObject var themeManager = ThemeManager()
    @State private var selectedTab = 0
    @State private var sheetType: SheetType?
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var expenseToDelete: Expense?
    
    enum SheetType: Identifiable {
        case ledgerDrawer
        case addLedger
        case addExpense
        case editLedger(Ledger)
        case memberManagement(Ledger)

        var id: String {
            switch self {
            case .ledgerDrawer: return "ledgerDrawer"
            case .addLedger: return "addLedger"
            case .addExpense: return "addExpense"
            case .editLedger(let ledger): return "editLedger-\(ledger.id.uuidString)"
            case .memberManagement(let ledger): return "memberMgmt-\(ledger.id.uuidString)"
            }
        }
    }

    var body: some View {
        Group {
            if auth.user != nil {
                TabView(selection: $selectedTab) {
                    ledgerTabView
                        .tabItem {
                            Label("账本", systemImage: "book.fill")
                        }
                        .tag(0)
                        .onAppear {
                            // Use user ID from AuthManager
                            if let userId = auth.user?.id {
                                ledgerStore.bind(userId: userId)
                            }
                        }

                    SettingsView()
                        .tabItem {
                            Label("设置", systemImage: "gearshape.fill")
                        }
                        .tag(1)
                }
                .tint(.blue)
            } else {
                LoginView()
            }
        }
        .environmentObject(auth)
        .environmentObject(ledgerStore)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.applyTheme())
        .sheet(item: $sheetType) { item in
            switch item {
            case .ledgerDrawer:
                LedgerDrawerView(
                    showingAddLedger: { sheetType = .addLedger },
                    editingLedger: { ledger in sheetType = .editLedger(ledger) }
                )
                .environmentObject(auth)
                .environmentObject(ledgerStore)

            case .addLedger:
                AddLedgerView { newLedger in
                    // 回调由 AddLedgerView 自己处理
                }
                .environmentObject(auth)
                .environmentObject(ledgerStore)

            case .addExpense:
                if let ledger = ledgerStore.currentLedger {
                    AddExpenseView(participants: ledger.participants) { newExpense in
                        ledgerStore.addExpense(newExpense, to: ledger) { result in
                            switch result {
                            case .success:
                                sheetType = nil
                            case .failure(let error):
                                print("Failed to add expense: \(error)")
                            }
                        }
                    }
                }

            case .editLedger(let ledger):
                AddLedgerView(ledger: ledger) { updated in
                    if !updated.title.isEmpty {
                        var merged = updated
                        merged.expenses = ledger.expenses
                        ledgerStore.updateLedger(merged)
                    }
                    sheetType = nil
                }
                .environmentObject(ledgerStore)
                .environmentObject(auth)

            case .memberManagement(let ledger):
                AddMemberView(ledger: ledger)
                    .environmentObject(ledgerStore)
            }
        }
    }

    @ViewBuilder
    private var ledgerTabView: some View {
        NavigationStack {
            Group {
                if ledgerStore.ledgers.isEmpty {
                    emptyStateView
                } else if let ledger = ledgerStore.currentLedger {
                    ledgerDetailView(ledger)
                } else {
                    ContentUnavailableView(
                        "请选择账本",
                        systemImage: "book.closed",
                        description: Text("从左侧选择一个账本")
                    )
                }
            }
            .navigationTitle(ledgerStore.currentLedger?.title ?? "账本")
            .searchable(text: $searchText, prompt: "搜索账单")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.impact(.light)
                        sheetType = .ledgerDrawer
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .buttonStyle(.spring(.light))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            HapticManager.impact(.medium)
                            sheetType = .addExpense
                        } label: {
                            Label("添加账单", systemImage: "plus.circle")
                        }

                        Button {
                            HapticManager.impact(.medium)
                            if let currentLedger = ledgerStore.currentLedger {
                                sheetType = .memberManagement(currentLedger)
                            }
                        } label: {
                            Label("管理成员", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .environmentObject(auth)
        .environmentObject(ledgerStore)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("暂无账本", systemImage: "book.closed")
        } description: {
            Text("点击左上角菜单添加第一个账本")
        } actions: {
            Button {
                sheetType = .addLedger
            } label: {
                Text("添加账本")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func ledgerDetailView(_ ledger: Ledger) -> some View {
        let filteredExpenses: [Expense] = {
            if searchText.isEmpty {
                return ledger.expenses
            }
            return ledger.expenses.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.payer.name.localizedCaseInsensitiveContains(searchText)
            }
        }()
        
        return List {
            Section {
                if ledger.expenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("暂无账单")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("点击右上角添加第一笔账单")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else if filteredExpenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("未找到匹配的账单")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(filteredExpenses) { expense in
                        expenseRowView(expense)
                            .listRowAnimation()
                    }
	                    .onDelete { indexSet in
	                        HapticManager.notificationOccurred(.warning)
	                        for index in indexSet.sorted(by: >) {
	                            let expense = filteredExpenses[index]
	                            ledgerStore.deleteExpense(expense, from: ledger) { _ in }
	                        }
	                    }
	                }
            } header: {
                Text("账单")
            }

            Section {
                let results = calculateBalanceResults(for: ledger)
                if results.isEmpty {
                    Text("暂无参与者")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { result in
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
            }

            Section {
                let transfers = calculateTransfers(for: ledger)
                if transfers.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("账目已结清")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(transfers) { transfer in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transfer.from.name)
                                    .font(.subheadline)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(transfer.to.name)
                                    .font(.subheadline)
                            }
                            .frame(width: 80)
                            
                            Spacer()
                            
                            Text(formatAmount(transfer.amount))
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Text("结算方案")
            }
	        }
	        .listStyle(.insetGrouped)
	        .scrollDismissesKeyboard(.interactively)
	    }

    private func expenseRowView(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                    .lineLimit(1)
                    .dynamicTypeSize(.accessibility2)
                
                HStack(spacing: 8) {
                    Label(expense.payer.name, systemImage: "person")
                    if expense.participants.count > 1 {
                        Label("\(expense.participants.count)人分摊", systemImage: "person.2")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(formatAmount(expense.amount))
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helper Methods

    private func formatAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "¥0"
    }

    private func isZero(_ amount: Decimal) -> Bool {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return abs(value) < 0.0001
    }

    private func calculateBalanceResults(for ledger: Ledger) -> [BalanceResult] {
        var balances: [Person: Decimal] = [:]
        for participant in ledger.participants {
            balances[participant] = 0
        }

        for expense in ledger.expenses {
            if expense.participants.isEmpty { continue }
            let share = expense.amount / Decimal(expense.participants.count)
            balances[expense.payer, default: 0] += expense.amount - share
            for participant in expense.participants where participant != expense.payer {
                balances[participant, default: 0] -= share
            }
        }

        return balances.map { BalanceResult(person: $0.key, balance: $0.value) }
            .sorted { $0.person.name < $1.person.name }
    }

    private func calculateTransfers(for ledger: Ledger) -> [Transfer] {
        let results = calculateBalanceResults(for: ledger)
        var creditors = results.filter { $0.balance > 0 }
            .map { ($0.person, $0.balance) }
            .sorted { $0.1 > $1.1 }
        var debtors = results.filter { $0.balance < 0 }
            .map { ($0.person, -$0.balance) }
            .sorted { $0.1 > $1.1 }

        var transfers: [Transfer] = []
        var i = 0
        var j = 0
        while i < debtors.count, j < creditors.count {
            let pay = min(debtors[i].1, creditors[j].1)
            if isZero(pay) { break }
            transfers.append(Transfer(from: debtors[i].0, to: creditors[j].0, amount: pay))
            debtors[i].1 -= pay
            creditors[j].1 -= pay
            if isZero(debtors[i].1) { i += 1 }
            if isZero(creditors[j].1) { j += 1 }
        }
        return transfers
    }
}

// MARK: - Supporting Types

struct BalanceResult: Identifiable {
    let id = UUID()
    let person: Person
    let balance: Decimal

    var isPositive: Bool { balance > 0 }

    var displayText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let amountStr = formatter.string(from: NSDecimalNumber(decimal: abs(balance))) ?? "¥0"

        if balance > 0 {
            return "应收 \(amountStr)"
        } else if balance < 0 {
            return "应付 \(amountStr)"
        }
        return "已结清"
    }
}

struct Transfer: Identifiable {
    let id = UUID()
    let from: Person
    let to: Person
    let amount: Decimal
}

#Preview {
    ContentView()
}
