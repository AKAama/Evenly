//
//  ContentView.swift
//  Evenly
//
//  Main content view with tab navigation and modern design
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var auth = AuthManager()
    @StateObject var ledgerStore = LedgerStore()
    @StateObject var themeManager = ThemeManager()
    @State private var selectedTab = 0
    @State private var sheetType: SheetType?
    @State private var searchText = ""
    @State private var expenseFilter: ExpenseFilter = .involvingMe
    @State private var showingDeleteConfirmation = false
    @State private var expenseToDelete: Expense?
    @State private var expenseDeleteLedgerId: UUID?
    @State private var settlementSuggestions: [Settlement] = []
    @State private var settlementHistory: [SettlementHistory] = []
    @State private var isLoadingSettlementData = false
    @State private var settlementError: String?
    @State private var settlementActionIds: Set<String> = []
    @State private var settlementToConfirm: Settlement?
    @State private var pendingSettlementLedgerId: UUID?
    @State private var loadedSettlementLedgerId: UUID?
    @State private var respondingExpenseIds: Set<UUID> = []
    @State private var actionError: String?
    @State private var showingLeaveLedgerAlert = false

    private enum ExpenseFilter: String, CaseIterable, Identifiable {
        case involvingMe = "有我参与"
        case createdByMe = "我创建的"
        case all = "全部"

        var id: Self { self }

        var next: Self {
            switch self {
            case .involvingMe: return .createdByMe
            case .createdByMe: return .all
            case .all: return .involvingMe
            }
        }

        var emptyTitle: String {
            switch self {
            case .involvingMe: return "暂无你参与的账单"
            case .createdByMe: return "暂无你创建的账单"
            case .all: return "暂无账单"
            }
        }
    }
    
    enum SheetType: Identifiable {
        case ledgerDrawer
        case addLedger
        case addExpense
        case memberManagement(Ledger)
        case memberList(Ledger)
        case expenseDetail(Expense, Ledger)

        var id: String {
            switch self {
            case .ledgerDrawer: return "ledgerDrawer"
            case .addLedger: return "addLedger"
            case .addExpense: return "addExpense"
            case .memberManagement(let ledger): return "memberMgmt-\(ledger.id.uuidString)"
            case .memberList(let ledger): return "memberList-\(ledger.id.uuidString)"
            case .expenseDetail(let expense, _): return "expense-\(expense.id.uuidString)"
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
            } else if auth.isGuestMode {
                GuestModeView()
            } else {
                LoginView()
            }
        }
        .environmentObject(auth)
        .environmentObject(ledgerStore)
        .environmentObject(themeManager)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, auth.user != nil {
                ledgerStore.fetchLedgers()
            }
        }
        .preferredColorScheme(themeManager.applyTheme())
        .sheet(item: $sheetType) { item in
            switch item {
            case .ledgerDrawer:
                LedgerDrawerView(
                    showingAddLedger: { sheetType = .addLedger }
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
                    AddExpenseView(participants: ledger.participants, currentUserId: auth.user?.id) { newExpense in
                        await withCheckedContinuation { continuation in
                            ledgerStore.addExpense(newExpense, to: ledger) { result in
                                switch result {
                                case .success:
                                    loadSettlementData(for: ledger)
                                    continuation.resume(returning: .success(()))
                                case .failure(let error):
                                    continuation.resume(returning: .failure(error))
                                }
                            }
                        }
                    }
                }

            case .memberManagement(let ledger):
                AddMemberView(ledgerId: ledger.id)
                    .environmentObject(auth)
                    .environmentObject(ledgerStore)

            case .memberList(let ledger):
                NavigationStack { LedgerMembersView(ledger: ledger) }

            case .expenseDetail(let expense, let ledger):
                NavigationStack { ExpenseDetailView(expense: expense, ledger: ledger) }
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .alert("退出账本", isPresented: $showingLeaveLedgerAlert) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                if let ledger = ledgerStore.currentLedger {
                    leaveLedger(ledger)
                }
            }
        } message: {
            Text("退出后将无法继续查看该账本。")
        }
        .confirmationDialog(
            settlementConfirmTitle,
            isPresented: Binding(
                get: { settlementToConfirm != nil },
                set: { if !$0 { settlementToConfirm = nil; pendingSettlementLedgerId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(settlementConfirmConfirmLabel, role: .destructive) {
                confirmSettlementFromDialog()
            }
            Button("取消", role: .cancel) {
                settlementToConfirm = nil
                pendingSettlementLedgerId = nil
            }
        } message: {
            Text(settlementConfirmMessage)
        }
        .alert("删除账单", isPresented: Binding(
            get: { expenseToDelete != nil },
            set: { if !$0 { expenseToDelete = nil; expenseDeleteLedgerId = nil } }
        )) {
            Button("删除", role: .destructive) {
                confirmDeleteExpense()
            }
            Button("取消", role: .cancel) {
                expenseToDelete = nil
                expenseDeleteLedgerId = nil
            }
        } message: {
            if let expense = expenseToDelete {
                Text("确定删除「\(expense.title)」？此操作无法撤销。")
            }
        }
    }

    private var settlementConfirmTitle: String { "确认转账" }

    private var settlementConfirmConfirmLabel: String {
        guard let s = settlementToConfirm else { return "确认" }
        return s.fromUserId == auth.user?.id ? "确认已转账" : "确认已收款"
    }

    private var settlementConfirmMessage: String {
        guard let s = settlementToConfirm else { return "" }
        let amount = formatAmount(s.amount)
        if s.fromUserId == auth.user?.id {
            return "确认已转账 \(amount) 给 \(s.toUserName)？"
        } else {
            return "确认已收到 \(s.fromUserName) 转账 \(amount)？"
        }
    }

    private func confirmSettlementFromDialog() {
        guard let settlement = settlementToConfirm else { return }
        let ledger: Ledger?
        if let lid = pendingSettlementLedgerId {
            ledger = ledgerStore.ledgers.first(where: { $0.id == lid }) ?? ledgerStore.currentLedger
        } else {
            ledger = ledgerStore.currentLedger
        }
        guard let ledger else {
            settlementToConfirm = nil
            pendingSettlementLedgerId = nil
            return
        }
        recordSettlement(settlement, in: ledger)
        settlementToConfirm = nil
        pendingSettlementLedgerId = nil
    }

    private func confirmDeleteExpense() {
        guard let expense = expenseToDelete else { return }
        let ledger: Ledger?
        if let lid = expenseDeleteLedgerId {
            ledger = ledgerStore.ledgers.first(where: { $0.id == lid }) ?? ledgerStore.currentLedger
        } else {
            ledger = ledgerStore.currentLedger
        }
        guard let ledger else {
            expenseToDelete = nil
            expenseDeleteLedgerId = nil
            return
        }
        ledgerStore.deleteExpense(expense, from: ledger) { result in
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
                loadSettlementData(for: ledger)
            case .failure(let error):
                HapticManager.notificationOccurred(.error)
                actionError = error.localizedDescription
            }
        }
        expenseToDelete = nil
        expenseDeleteLedgerId = nil
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
            .safeAreaInset(edge: .top) {
                if let invitation = ledgerStore.invitations.first {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("账本邀请").font(.caption).foregroundStyle(.secondary)
                            Text("\(invitation.invitedByName) 邀请你加入「\(invitation.ledgerName)」")
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        Button("拒绝") { ledgerStore.respondToInvitation(invitation, accept: false) }
                            .buttonStyle(.bordered)
                        Button("接受") { ledgerStore.respondToInvitation(invitation, accept: true) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                }
            }
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

                        if let currentLedger = ledgerStore.currentLedger,
                           currentLedger.ownerId == auth.user?.id {
                            Button {
                                HapticManager.impact(.medium)
                                sheetType = .memberManagement(currentLedger)
                            } label: {
                                Label("管理成员", systemImage: "person.badge.plus")
                            }
                        }

                        if let currentLedger = ledgerStore.currentLedger,
                           let userId = auth.user?.id,
                           currentLedger.ownerId != userId {
                            Divider()

                            Button(role: .destructive) {
                                HapticManager.notificationOccurred(.warning)
                                showingLeaveLedgerAlert = true
                            } label: {
                                Label("退出账本", systemImage: "rectangle.portrait.and.arrow.right")
                            }
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
            let scopedExpenses: [Expense]
            if let userId = auth.user?.id {
                switch expenseFilter {
                case .involvingMe:
                    scopedExpenses = ledger.expenses.filter { expense in
                        expense.participants.contains { $0.userId == userId }
                    }
                case .createdByMe:
                    scopedExpenses = ledger.expenses.filter { $0.createdBy == userId }
                case .all:
                    scopedExpenses = ledger.expenses
                }
            } else {
                scopedExpenses = ledger.expenses
            }

            guard !searchText.isEmpty else { return scopedExpenses }
            return scopedExpenses.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.payer.name.localizedCaseInsensitiveContains(searchText)
            }
        }()
        
        return List {
            Section {
                ledgerOverviewCard(ledger)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

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
                        Image(systemName: searchText.isEmpty ? "person.crop.circle.badge.questionmark" : "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text(searchText.isEmpty ? expenseFilter.emptyTitle : "未找到匹配的账单")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(filteredExpenses) { expense in
                        expenseRowView(expense, ledger: ledger)
                            .listRowAnimation()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                sheetType = .expenseDetail(expense, ledger)
                            }
                            .swipeActions(edge: .trailing) {
                                if expense.createdBy == auth.user?.id {
                                    Button(role: .destructive) {
                                        HapticManager.impact(.light)
                                        expenseToDelete = expense
                                        expenseDeleteLedgerId = ledger.id
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                    }
	                }
            } header: {
                HStack {
                    Text("账单")
                    Spacer()
                    Button {
                        expenseFilter = expenseFilter.next
                        HapticManager.selection.selectionChanged()
                    } label: {
                        HStack(spacing: 4) {
                            Text(expenseFilter.rawValue)
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .textCase(nil)
            }

            let mine = mySettlements(in: ledger)
            if isLoadingSettlementData || settlementError != nil || !mine.isEmpty {
                Section {
                    if isLoadingSettlementData {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let settlementError {
                        Label(settlementError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else {
                        ForEach(mine) { settlement in
                            mySettlementRow(settlement, ledger: ledger)
                        }
                    }
                } header: {
                    Text("与我相关的待结算")
                } footer: {
                    Text("只显示需要你付款或收款的项目，完成转账后点击右侧勾选")
                }
            }

            Section {
                if settlementHistory.isEmpty {
                    Text("暂无结算记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(SettlementHistory.merging(settlementHistory)) { settlement in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(settlement.fromUserName) → \(settlement.toUserName)")
                                    .font(.subheadline)
                                if let settledAt = settlement.settledAt {
                                    Text(formatDate(settledAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatAmount(settlement.amount))
                                .font(.headline)
                        }
                    }
                }
            } header: {
                Text("已结算记录")
            } footer: {
                Text("这里保存已标记完成的转账")
            }

            Section {
                NavigationLink {
                    SettlementDetailView(
                        ledger: ledger,
                        suggestions: settlementSuggestions
                    )
                } label: {
                    HStack {
                        Label("查看全部结算方案", systemImage: "list.bullet.rectangle.portrait")
                        Spacer()
                        if !settlementSuggestions.isEmpty {
                            Text("\(settlementSuggestions.count) 笔")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
	        }
	        .listStyle(.insetGrouped)
	        .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if loadedSettlementLedgerId != ledger.id {
                    loadedSettlementLedgerId = ledger.id
                    loadSettlementData(for: ledger)
                }
            }
            .onChange(of: ledger.id) { _, _ in
                loadedSettlementLedgerId = ledger.id
                loadSettlementData(for: ledger)
            }
	    }

    private func ledgerOverviewCard(_ ledger: Ledger) -> some View {
        let total = ledger.expenses.reduce(Decimal.zero) { $0 + $1.amount }
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("账本总支出")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                Text(formatAmount(total))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button {
                    sheetType = .memberList(ledger)
                    HapticManager.impact(.light)
                } label: {
                    overviewMetric(icon: "person.2.fill", value: "\(ledger.participantCount)", label: "成员")
                }
                .buttonStyle(.plain)
                overviewMetric(icon: "receipt.fill", value: "\(ledger.expenses.count)", label: "账单")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(red: 0.10, green: 0.38, blue: 0.78))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: EvenlyStyle.blue.opacity(0.16), radius: 10, y: 5)
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }

    private func overviewMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
            Text("\(value) \(label)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.86))
        .frame(minWidth: 42)
    }

    private func expenseRowView(_ expense: Expense, ledger: Ledger) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatAmount(expense.amount))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    expenseStatusLabel(expense)
                }
            }

            if canRespond(to: expense) {
                HStack {
                    Spacer()
                    Button {
                        respond(to: expense, with: .rejected, in: ledger)
                    } label: {
                        Label("拒绝", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(respondingExpenseIds.contains(expense.id))

                    Button {
                        respond(to: expense, with: .confirmed, in: ledger)
                    } label: {
                        if respondingExpenseIds.contains(expense.id) {
                            ProgressView()
                        } else {
                            Text("确认")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(respondingExpenseIds.contains(expense.id))
                }
            } else if let userStatus = currentUserConfirmationStatus(for: expense), expense.status == .pending {
                Label(userStatus == .confirmed ? "你已确认" : "你已拒绝", systemImage: userStatus == .confirmed ? "checkmark.circle" : "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(userStatus == .confirmed ? .green : .red)
            }
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func expenseStatusLabel(_ expense: Expense) -> some View {
        switch expense.status {
        case .pending:
            Label("待确认", systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(.orange)
        case .confirmed:
            Label("已确认", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .rejected:
            Label("已拒绝", systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func canRespond(to expense: Expense) -> Bool {
        guard expense.status == .pending,
              let userId = auth.user?.id,
              expense.createdBy != userId,
              expense.participants.contains(where: { $0.userId == userId }) else {
            return false
        }
        return expense.confirmations[userId] == nil
    }

    private func currentUserConfirmationStatus(for expense: Expense) -> ConfirmationStatus? {
        guard let userId = auth.user?.id else { return nil }
        return expense.confirmations[userId]
    }

    private func respond(to expense: Expense, with status: ConfirmationStatus, in ledger: Ledger) {
        respondingExpenseIds.insert(expense.id)
        ledgerStore.respondToExpense(expense, status: status, in: ledger) { result in
            respondingExpenseIds.remove(expense.id)
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
                loadSettlementData(for: ledger)
            case .failure(let error):
                HapticManager.notificationOccurred(.error)
                actionError = error.localizedDescription
            }
        }
    }

    private func loadSettlementData(for ledger: Ledger) {
        isLoadingSettlementData = true
        settlementError = nil

        ledgerStore.fetchSettlements(for: ledger) { result in
            switch result {
            case .success(let settlements):
                settlementSuggestions = settlements
            case .failure(let error):
                settlementError = error.localizedDescription
            }

            ledgerStore.fetchSettlementHistory(for: ledger) { historyResult in
                isLoadingSettlementData = false
                switch historyResult {
                case .success(let history):
                    settlementHistory = history
                case .failure(let error):
                    settlementError = error.localizedDescription
                }
            }
        }
    }

    /// 与当前用户相关的待结算:我需转给别人的 + 别人需转给我的
    /// 后端返回的 suggestions 已经扣除了已记录的转账金额，这里只需过滤出涉及当前用户的。
    private func mySettlements(in ledger: Ledger) -> [Settlement] {
        guard let me = auth.user?.id else { return [] }
        return settlementSuggestions.compactMap { suggestion in
            guard suggestion.fromUserId == me || suggestion.toUserId == me else { return nil }
            guard suggestion.amount > 0 else { return nil }
            return Settlement(
                id: suggestion.id,
                fromUserId: suggestion.fromUserId,
                fromUserName: suggestion.fromUserName,
                toUserId: suggestion.toUserId,
                toUserName: suggestion.toUserName,
                amount: suggestion.amount
            )
        }
    }

    @ViewBuilder
    private func mySettlementRow(_ settlement: Settlement, ledger: Ledger) -> some View {
        let me = auth.user?.id
        let iOwe = settlement.fromUserId == me
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iOwe ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: iOwe ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(iOwe ? .orange : .green)
            }

            VStack(alignment: .leading, spacing: 2) {
                if iOwe {
                    Text("我需转给 \(settlement.toUserName)")
                        .font(.subheadline)
                } else {
                    Text("\(settlement.fromUserName) 需转给我")
                        .font(.subheadline)
                }
            }

            Spacer()

            Text(formatAmount(settlement.amount))
                .font(.headline)
                .foregroundStyle(iOwe ? .orange : .green)

            Button {
                HapticManager.impact(.light)
                // Capture the ledger and settlement in the dialog via state
                pendingSettlementLedgerId = ledger.id
                settlementToConfirm = settlement
            } label: {
                if settlementActionIds.contains(settlement.id) {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.circle")
                }
            }
            .buttonStyle(.borderless)
            .disabled(settlementActionIds.contains(settlement.id))
        }
        .padding(.vertical, 2)
    }

    private func recordSettlement(_ settlement: Settlement, in ledger: Ledger) {
        settlementActionIds.insert(settlement.id)
        ledgerStore.createSettlement(
            from: settlement.fromUserId,
            to: settlement.toUserId,
            amount: settlement.amount,
            for: ledger
        ) { result in
            settlementActionIds.remove(settlement.id)
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
                loadSettlementData(for: ledger)
            case .failure(let error):
                HapticManager.notificationOccurred(.error)
                actionError = error.localizedDescription
            }
        }
    }

    private func leaveLedger(_ ledger: Ledger) {
        ledgerStore.leaveLedger(ledger) { result in
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
            case .failure(let error):
                HapticManager.notificationOccurred(.error)
                actionError = error.localizedDescription
            }
        }
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
