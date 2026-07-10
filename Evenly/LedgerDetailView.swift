//
//  LedgerDetailView.swift
//  Evenly
//
//  Created by alex_yehui on 2025/12/14.
//  Modern ledger detail with animations and haptics
//

import SwiftUI

struct LedgerDetailView: View {

    let ledgerId: UUID
    @EnvironmentObject var store: LedgerStore
    @EnvironmentObject var auth: AuthManager
    @State private var showingAddExpense = false
    @State private var showingDeleteLedgerAlert = false
    @State private var expenseToDelete: Expense?
    @State private var deleteError: String?
    @State private var searchText = ""
    
    struct BalanceResult: Identifiable {
        let id = UUID()
        let person: Person
        let balance: Decimal // 正数表示需要收取的金额，负数表示需要支付的金额
        
        var isPositive: Bool {
            return balance > 0
        }
        
        var displayText: String {
            if balance > 0 {
                return "应收: \(formatAmount(balance))"
            } else if balance < 0 {
                return "应付: \(formatAmount(abs(balance)))"
            } else {
                return "收支平衡"
            }
        }
    }
    
    var balanceResults: [BalanceResult] {
        guard let ledger = ledger else { return [] }
        var balances: [Person: Decimal] = [:]
        
        // 初始化每个人的余额为0
        for participant in ledger.participants {
            balances[participant] = 0
        }
        
        // 计算每笔支出的分账
        for expense in ledger.expenses {
            if expense.participants.isEmpty {
                continue
            }
            
            let share = expense.amount / Decimal(expense.participants.count)
            
            // 付款人应收取的金额 = 总金额 - 自己的份额
            balances[expense.payer, default: 0] += expense.amount - share
            
            // 其他参与人应支付的金额 = 份额
            for participant in expense.participants {
                if participant != expense.payer {
                    balances[participant, default: 0] -= share
                }
            }
        }
        
        // 转换为BalanceResult数组并排序
        return balances.map { BalanceResult(person: $0.key, balance: $0.value) }
            .sorted { $0.person.name < $1.person.name }
    }

    struct Transfer: Identifiable {
        let id = UUID()
        let from: Person
        let to: Person
        let amount: Decimal
    }
    
    var transfers: [Transfer] {
        let results = balanceResults
        var creditors: [(Person, Decimal)] = results
            .filter { $0.balance > 0 }
            .map { ($0.person, $0.balance) }
            .sorted { $0.1 > $1.1 }
        var debtors: [(Person, Decimal)] = results
            .filter { $0.balance < 0 }
            .map { ($0.person, -$0.balance) } // 转为正数欠款
            .sorted { $0.1 > $1.1 }
        
        var output: [Transfer] = []
        var i = 0
        var j = 0
        while i < debtors.count, j < creditors.count {
            let pay = min(debtors[i].1, creditors[j].1)
            if isZero(pay) { break }
            output.append(Transfer(from: debtors[i].0, to: creditors[j].0, amount: pay))
            
            debtors[i].1 -= pay
            creditors[j].1 -= pay
            
            if isZero(debtors[i].1) { i += 1 }
            if isZero(creditors[j].1) { j += 1 }
        }
        return output
    }
    
    private var ledger: Ledger? {
        store.ledgers.first(where: { $0.id == ledgerId })
    }

    var body: some View {
        contentWithAlerts
    }

    private var contentWithAlerts: some View {
        contentWithSheet
            .alert("删除账本", isPresented: $showingDeleteLedgerAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let ledger = ledger {
                        store.deleteLedger(ledger) { error in
                            if let error {
                                deleteError = error.localizedDescription
                            }
                        }
                    }
                }
            } message: {
                Text("确定要删除账本「\(ledger?.title ?? "")」吗？此操作不可撤销。")
            }
            .alert(
                "删除账单",
                isPresented: Binding(
                    get: { expenseToDelete != nil },
                    set: { if !$0 { expenseToDelete = nil } }
                ),
                presenting: expenseToDelete
            ) { _ in
                Button("删除", role: .destructive) {
                    if let expense = expenseToDelete {
                        performDeleteExpense(expense)
                    }
                }
                Button("取消", role: .cancel) {
                    expenseToDelete = nil
                }
            } message: { _ in
                Text(deleteExpenseMessage)
            }
            .alert("操作失败", isPresented: showingDeleteError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
    }

    private var contentWithSheet: some View {
        contentWithToolbar
            .sheet(isPresented: $showingAddExpense) {
                addExpenseSheet
            }
    }

    private var contentWithToolbar: some View {
        contentRoot
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddExpense = true
                        } label: {
                            Label("添加账单", systemImage: "plus.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteLedgerAlert = true
                        } label: {
                            Label("删除账本", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
    }

    @ViewBuilder
    private var contentRoot: some View {
        if let ledger = ledger {
            List {
                expenseSection(ledger)
                balanceSection
                transferSection
            }
            .navigationTitle(ledger.title)
        } else {
            Text("账本不存在")
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func expenseSection(_ ledger: Ledger) -> some View {
        Section(header: Text("账单")) {
            if ledger.expenses.isEmpty {
                Text("暂无账单记录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(ledger.expenses) { expense in
                    expenseRow(expense)
                }
            }
        }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(expense.title)
                    .font(.headline)
                    .dynamicTypeSize(.accessibility2)
                Spacer()
                Text(formatAmount(expense.amount))
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            HStack {
                Text("付款人: \(expense.payer.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                Text("参与人: \(expense.participants.map { $0.name }.joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if !expense.confirmations.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("确认状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(expense.participants) { participant in
                        ConfirmationStatusRow(
                            participant: participant,
                            status: expense.confirmationStatus(for: participant)
                        )
                    }
                }
            }

            Divider()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if expense.createdBy == auth.user?.id {
                Button(role: .destructive) {
                    HapticManager.impact(.light)
                    expenseToDelete = expense
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .listRowAnimation()
    }

    private var balanceSection: some View {
        Section(header: Text("分账结果")) {
            ForEach(balanceResults) { result in
                balanceRow(result)
            }
        }
    }

    private func balanceRow(_ result: BalanceResult) -> some View {
        let color: Color = result.isPositive ? .green : result.balance < 0 ? .red : .secondary
        return HStack {
            Text(result.person.name)
                .font(.headline)
            Spacer()
            VStack(alignment: .trailing) {
                Text(result.displayText)
                    .font(.subheadline)
                    .foregroundColor(color)
                Text(formatAmount(result.balance))
                    .font(.headline)
                    .foregroundColor(color)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var transferSection: some View {
        Section(header: Text("结算转账方案")) {
            if transfers.isEmpty {
                Text("暂无需要结算的转账")
                    .foregroundColor(.secondary)
            } else {
                ForEach(transfers) { transfer in
                    HStack {
                        Text("\(transfer.from.name) → \(transfer.to.name)")
                        Spacer()
                        Text(formatAmount(transfer.amount))
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var addExpenseSheet: some View {
        if let ledger = ledger {
            AddExpenseView(participants: ledger.participants, currentUserId: auth.user?.id, ledgerId: ledger.id) { newExpense in
                await submitAddExpense(newExpense, to: ledger)
            }
        }
    }

    private func submitAddExpense(_ expense: Expense, to ledger: Ledger) async -> Result<Void, Error> {
        guard !expense.title.isEmpty else {
            return .failure(NSError(
                domain: "AddExpense",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "请输入账单名称"]
            ))
        }
        return await withCheckedContinuation { continuation in
            store.addExpense(expense, to: ledger) { result in
                switch result {
                case .success:
                    continuation.resume(returning: .success(()))
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    private var showingDeleteError: Binding<Bool> {
        Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )
    }

    private var deleteExpenseMessage: String {
        guard let expense = expenseToDelete else { return "" }
        return "确定删除「\(expense.title)」？此操作无法撤销。"
    }

    private func performDeleteExpense(_ expense: Expense) {
        guard let ledger = ledger else {
            expenseToDelete = nil
            return
        }
        store.deleteExpense(expense, from: ledger) { result in
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
            case .failure(let error):
                HapticManager.notificationOccurred(.error)
                deleteError = error.localizedDescription
            }
        }
        expenseToDelete = nil
    }
}

struct ConfirmationStatusRow: View {
    let participant: Person
    let status: ConfirmationStatus
    
    var body: some View {
        HStack(spacing: 8) {
            Text(participant.name)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 4) {
                statusIcon
                statusText
            }
            .font(.caption)
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .confirmed:
            Image(systemName: "checkmark")
                .foregroundColor(.green)
        case .pending:
            Image(systemName: "hourglass")
                .foregroundColor(.orange)
        case .rejected:
            Image(systemName: "xmark")
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .confirmed:
            Text("已确认")
                .foregroundColor(.green)
        case .pending:
            Text("待确认")
                .foregroundColor(.orange)
        case .rejected:
            Text("已否决")
                .foregroundColor(.red)
        }
    }
}

func formatAmount(_ amount: Decimal) -> String {
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
