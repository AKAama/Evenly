//
//  ContentView.swift
//  Evenly
//
//  Main content view with tab navigation and modern design
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @StateObject var auth = AuthManager()
    @StateObject var ledgerStore = LedgerStore()
    @StateObject var themeManager = ThemeManager()
    @StateObject private var notifications = NotificationManager.shared
    @State private var selectedTab = 0
    @State private var sheetType: SheetType?
    @State private var searchText = ""
    @State private var expenseFilter: ExpenseFilter = .involvingMe
    @State private var showingDeleteConfirmation = false
    @State private var expenseToDelete: Expense?
    @State private var expenseDeleteLedgerId: UUID?
    @State private var settlementSuggestions: [Settlement] = []
    @State private var isLoadingSettlementData = false
    @State private var settlementError: String?
    @State private var loadedSettlementLedgerId: UUID?
    @State private var respondingExpenseIds: Set<UUID> = []
    @State private var actionError: String?
    @State private var showingLeaveLedgerAlert = false
    @State private var showingDeleteLedgerAlert = false
    @State private var joinToast: String?
    @State private var isHandlingJoinLink = false
    @State private var shareSnapshot: LedgerShareSnapshot?
    @ObservedObject private var deepLinks = DeepLinkInbox.shared
    /// iPad split shell only (phone TabView unchanged).
    @State private var iPadSidebar: IPadSidebarItem = .ledgers
    @State private var iPadShowAllSettlements = false
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
        case editExpense(Expense, Ledger)
        /// Single members surface: roster for all; invite/manage tools for owner only.
        case members(Ledger)
        case expenseDetail(Expense, Ledger)

        var id: String {
            switch self {
            case .ledgerDrawer: return "ledgerDrawer"
            case .addLedger: return "addLedger"
            case .addExpense: return "addExpense"
            case .editExpense(let expense, _): return "editExpense-\(expense.id.uuidString)"
            case .members(let ledger): return "members-\(ledger.id.uuidString)"
            case .expenseDetail(let expense, _): return "expense-\(expense.id.uuidString)"
            }
        }
    }

    var body: some View {
        contentWithAlerts
    }

    private var contentWithAlerts: some View {
        contentWithSheet
            // Do not force username/name/email setup after Sign in with Apple —
            // App Store Guideline 4 / SIWA: use Authentication Services data only.
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
            .alert("删除账本", isPresented: $showingDeleteLedgerAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let ledger = ledgerStore.currentLedger {
                        deleteCurrentLedger(ledger)
                    }
                }
            } message: {
                Text("将永久删除「\(ledgerStore.currentLedger?.title ?? "该账本")」及其中账单，此操作无法撤销。")
            }
            .alert(
                "删除账单",
                isPresented: Binding(
                    get: { expenseToDelete != nil },
                    set: { if !$0 { expenseToDelete = nil; expenseDeleteLedgerId = nil } }
                ),
                presenting: expenseToDelete
            ) { _ in
                Button("删除", role: .destructive) {
                    confirmDeleteExpense()
                }
                Button("取消", role: .cancel) {
                    expenseToDelete = nil
                    expenseDeleteLedgerId = nil
                }
            } message: { _ in
                Text(expenseDeleteMessage)
            }
    }

    private var contentWithSheet: some View {
        contentRoot
            .sheet(item: $sheetType) { item in
                sheetContent(for: item)
            }
            .sheet(item: $shareSnapshot) { snapshot in
                LedgerShareSheet(snapshot: snapshot)
            }
    }

    private var contentRoot: some View {
        Group {
            if auth.user != nil {
                if auth.isPlatformUser {
                    // Same login page; platform accounts get an ops shell instead of ledgers.
                    // TODO(iPad): optional wide-layout ops shell; phone ops unchanged for now.
                    PlatformConsoleRootView()
                } else if EvenlyDeviceLayout.isPadIdiom {
                    // iPad-only wide shell. Phone TabView path below is unchanged.
                    IPadAppShell(
                        selectedSidebar: $iPadSidebar,
                        onAddLedger: {
                            sheetType = .addLedger
                        }
                    ) {
                        iPadDetailRoot
                    }
                    .safeAreaInset(edge: .top) {
                        invitationBanner
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        ledgerTabView
                            .tabItem {
                                Label("账本", systemImage: "book.fill")
                            }
                            .tag(0)

                        SettingsView()
                            .tabItem {
                                Label("设置", systemImage: "gearshape.fill")
                            }
                            .tag(1)
                    }
                    .tint(EvenlyStyle.brandBlue)
                    // Keep invite banner above every tab so it is not limited to the ledger screen.
                    .safeAreaInset(edge: .top) {
                        invitationBanner
                    }
                }
            } else if auth.isGuestMode {
                GuestModeView()
            } else {
                LoginView()
            }
        }
        .environmentObject(auth)
        .environmentObject(ledgerStore)
        .environmentObject(themeManager)
        .onChange(of: auth.user?.id) { _, userID in
            if let userID {
                // Always land on the ledger tab after login / session restore.
                selectedTab = 0
                iPadSidebar = .ledgers
                if auth.isPlatformUser {
                    // Ops accounts do not participate in ledgers / guest data.
                    ledgerStore.stop()
                } else {
                    ledgerStore.bind(userId: userID)
                    Task { await notifications.requestAuthorizationAndRegister() }
                    routePendingNotification()
                    consumePendingJoinTokenIfNeeded()
                }
            } else {
                ledgerStore.stop()
            }
        }
        // Also attach here so links still work if the WindowGroup handlers race with mount.
        .onOpenURL { url in
            deepLinks.handle(url: url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            deepLinks.handle(userActivity: activity)
        }
        .onChange(of: deepLinks.pendingJoinToken) { _, token in
            guard token != nil else { return }
            consumePendingJoinTokenIfNeeded()
        }
        .onChange(of: notifications.pendingDestination) { _, _ in
            routePendingNotification()
        }
        .onChange(of: notifications.remoteRefreshTick) { _, _ in
            guard auth.user != nil else { return }
            // Push arrived while app is open (or background-woken): pull invite banner ASAP.
            ledgerStore.refreshInvitations()
            ledgerStore.fetchLedgers()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, let userID = auth.user?.id {
                if auth.isPlatformUser {
                    ledgerStore.stop()
                } else {
                    ledgerStore.bind(userId: userID)
                    Task { await notifications.requestAuthorizationAndRegister() }
                    consumePendingJoinTokenIfNeeded()
                }
            }
        }
        .onAppear {
            deepLinks.restorePersistedIfNeeded()
            if let userID = auth.user?.id {
                selectedTab = 0
                iPadSidebar = .ledgers
                if auth.isPlatformUser {
                    ledgerStore.stop()
                } else {
                    ledgerStore.bind(userId: userID)
                    Task { await notifications.requestAuthorizationAndRegister() }
                }
            }
            if !auth.isPlatformUser {
                consumePendingJoinTokenIfNeeded()
            }
        }
        // Platform ops shell is designed for a fixed light palette (SAVO-style).
        // Forcing dark via ThemeManager made system labels white on our light cards.
        .preferredColorScheme(auth.isPlatformUser ? .light : themeManager.applyTheme())
        .overlay(alignment: .bottom) {
            if let joinToast {
                Text(joinToast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(EvenlyMotion.ui, value: joinToast)
    }

    private func consumePendingJoinTokenIfNeeded() {
        deepLinks.restorePersistedIfNeeded()
        guard let token = deepLinks.pendingJoinToken ?? DeepLinkRouter.loadPendingJoinToken(),
              !token.isEmpty else { return }

        // Cold start: session restore is async — wait briefly before asking user to log in.
        if auth.user == nil {
            Task { @MainActor in
                for _ in 0..<40 {
                    if auth.user != nil { break }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                if auth.user == nil {
                    auth.isGuestMode = false
                    joinToast = "登录后将自动加入账本"
                    HapticManager.notificationOccurred(.warning)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { joinToast = nil }
                    return
                }
                await performJoin(token: token)
            }
            return
        }

        Task { @MainActor in
            await performJoin(token: token)
        }
    }

    @MainActor
    private func performJoin(token: String) async {
        guard auth.user != nil else { return }
        guard !isHandlingJoinLink else { return }
        isHandlingJoinLink = true
        selectedTab = 0
        iPadSidebar = .ledgers
        do {
            let result = try await ledgerStore.joinViaInviteToken(token)
            deepLinks.clearPendingJoinToken()
            isHandlingJoinLink = false
            let message = result.status == "already_member"
                ? "你已在「\(result.ledgerName)」中"
                : "已加入「\(result.ledgerName)」"
            joinToast = message
            HapticManager.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                joinToast = nil
            }
        } catch {
            isHandlingJoinLink = false
            // Keep pending token so a retry after re-login still works.
            actionError = error.localizedDescription
            HapticManager.notificationOccurred(.error)
            print("[DeepLink] join failed: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private var invitationBanner: some View {
        if let invitation = ledgerStore.invitations.first {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("账本邀请").font(.caption).foregroundStyle(.secondary)
                    Text("\(invitation.invitedByName) 邀请你加入「\(invitation.ledgerName)」")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Button("拒绝") {
                    HapticManager.impact(.rigid, intensity: 0.75)
                    ledgerStore.respondToInvitation(invitation, accept: false)
                }
                .buttonStyle(.bordered)
                Button("接受") {
                    HapticManager.impact(.medium, intensity: 0.9)
                    ledgerStore.respondToInvitation(invitation, accept: true)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    private func routePendingNotification() {
        guard auth.user != nil, let destination = notifications.pendingDestination else { return }
        switch destination {
        case .ledger(let ledgerID):
            if let ledger = ledgerStore.ledgers.first(where: { $0.id == ledgerID }) {
                ledgerStore.currentLedger = ledger
                selectedTab = 0
                iPadSidebar = .ledgers
                notifications.consumeDestination()
            } else {
                ledgerStore.fetchLedgers()
            }
        case .invitations:
            selectedTab = 0
            iPadSidebar = .ledgers
            ledgerStore.refreshInvitations()
            ledgerStore.fetchLedgers()
            notifications.consumeDestination()
        }
    }

    @ViewBuilder
    private func sheetContent(for item: SheetType) -> some View {
        switch item {
        case .ledgerDrawer:
            LedgerDrawerView(
                showingAddLedger: { sheetType = .addLedger }
            )
            .environmentObject(auth)
            .environmentObject(ledgerStore)

        case .addLedger:
            AddLedgerView { _ in }
                .environmentObject(auth)
                .environmentObject(ledgerStore)

        case .addExpense:
            addExpenseSheet

        case .editExpense(let expense, let ledger):
            AddExpenseView(
                expense: expense,
                participants: ledger.participants,
                currentUserId: auth.user?.id,
                ledgerId: ledger.id,
                onSave: { edited in
                    await submitEditExpense(edited, to: ledger)
                }
            )

        case .members(let ledger):
            AddMemberView(ledgerId: ledger.id)
                .environmentObject(auth)
                .environmentObject(ledgerStore)

        case .expenseDetail(let expense, let ledger):
            NavigationStack {
                ExpenseDetailView(
                    expense: expense,
                    ledger: ledger,
                    currentUserId: auth.user?.id,
                    onEdit: {
                        sheetType = .editExpense(expense, ledger)
                    },
                    onSetRefund: { amount, note in
                        await withCheckedContinuation { continuation in
                            ledgerStore.setRefund(for: expense, amount: amount, note: note, in: ledger) { result in
                                if case .success = result {
                                    loadSettlementData(for: ledger)
                                }
                                continuation.resume(returning: result)
                            }
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var addExpenseSheet: some View {
        if let ledger = ledgerStore.currentLedger {
            AddExpenseView(
                participants: ledger.participants,
                currentUserId: auth.user?.id,
                ledgerId: ledger.id,
                onSave: { newExpense in
                    await submitAddExpense(newExpense, to: ledger)
                }
            )
        }
    }

    private func submitAddExpense(_ expense: Expense, to ledger: Ledger) async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            ledgerStore.addExpense(expense, to: ledger) { result in
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

    private func submitEditExpense(_ expense: Expense, to ledger: Ledger) async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            ledgerStore.updateExpense(expense, in: ledger) { result in
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

    private func canEditExpense(_ expense: Expense, in ledger: Ledger) -> Bool {
        expense.createdBy == auth.user?.id
            && expense.status != .rejected
            && (expense.status == .pending || !ledger.requireConfirmation)
    }

    private func openEditExpense(_ expense: Expense, in ledger: Ledger) {
        HapticManager.impact(.medium)
        sheetType = .editExpense(expense, ledger)
    }

    private var expenseDeleteMessage: String {
        guard let expense = expenseToDelete else { return "" }
        return "确定删除「\(expense.title)」？此操作无法撤销。"
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

    /// iPad detail column: wide workspace when a ledger is selected.
    @ViewBuilder
    private var iPadDetailRoot: some View {
        NavigationStack {
            Group {
                if ledgerStore.ledgers.isEmpty {
                    emptyStateView
                } else if let ledger = ledgerStore.currentLedger {
                    IPadLedgerWorkspace(
                        ledger: ledger,
                        expenses: filteredExpenses(for: ledger),
                        settlements: mySettlements(in: ledger),
                        isLoadingSettlements: isLoadingSettlementData,
                        settlementError: settlementError,
                        expenseFilterLabel: expenseFilter.rawValue,
                        respondingExpenseIds: respondingExpenseIds,
                        onCycleFilter: {
                            expenseFilter = expenseFilter.next
                        },
                        onAddExpense: {
                            sheetType = .addExpense
                        },
                        onMembers: {
                            sheetType = .members(ledger)
                        },
                        onShare: {
                            presentLedgerShare(for: ledger)
                        },
                        onOpenExpense: { expense in
                            openExpenseDetail(expense, in: ledger)
                        },
                        onConfirmExpense: { expense in
                            respond(to: expense, with: .confirmed, in: ledger)
                        },
                        onRejectExpense: { expense in
                            respond(to: expense, with: .rejected, in: ledger)
                        },
                        onEditExpense: { expense in
                            openEditExpense(expense, in: ledger)
                        },
                        onDeleteExpense: { expense in
                            prepareToDeleteExpense(expense, in: ledger)
                        },
                        onOpenAllSettlements: {
                            iPadShowAllSettlements = true
                        },
                        canRespond: { expense in
                            canRespond(to: expense, in: ledger)
                        },
                        canEdit: { expense in
                            canEditExpense(expense, in: ledger)
                        },
                        formatAmount: formatAmount
                    )
                    .navigationDestination(isPresented: $iPadShowAllSettlements) {
                        SettlementDetailView(
                            ledger: ledger,
                            suggestions: settlementSuggestions
                        )
                    }
                    .onAppear {
                        if loadedSettlementLedgerId != ledger.id {
                            loadedSettlementLedgerId = ledger.id
                            loadSettlementData(for: ledger)
                        } else if settlementSuggestions.isEmpty {
                            loadSettlementData(for: ledger)
                        }
                    }
                    .onChange(of: ledger.id) { _, _ in
                        loadedSettlementLedgerId = ledger.id
                        settlementSuggestions = []
                        loadSettlementData(for: ledger)
                    }
                    .toolbar {
                        if let userId = auth.user?.id, ledger.ownerId != userId {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .destructive) {
                                    HapticManager.notificationOccurred(.warning)
                                    showingLeaveLedgerAlert = true
                                } label: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                }
                                .accessibilityLabel("退出账本")
                            }
                        } else if ledger.ownerId == auth.user?.id {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .destructive) {
                                    HapticManager.notificationOccurred(.warning)
                                    showingDeleteLedgerAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("删除账本")
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("选择一本账本", systemImage: "books.vertical")
                    } description: {
                        Text("从左侧列表打开账本，或点 + 新建。")
                    } actions: {
                        Button("新建账本") {
                            sheetType = .addLedger
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .searchable(
                text: $searchText,
                prompt: ledgerStore.currentLedger == nil ? "搜索账本" : "搜索账单"
            )
        }
        .environmentObject(auth)
        .environmentObject(ledgerStore)
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
                    ledgerPickerView
                }
            }
            .navigationTitle(ledgerStore.currentLedger?.title ?? "选择账本")
            .searchable(
                text: $searchText,
                prompt: ledgerStore.currentLedger == nil ? "搜索账本" : "搜索账单"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        openLedgerDrawerFromMenuButton()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .buttonStyle(.spring(.light))
                    .accessibilityLabel("账本列表")
                }

                if let currentLedger = ledgerStore.currentLedger {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Single action — no nested menu for one item.
                        if let userId = auth.user?.id, currentLedger.ownerId != userId {
                            Button(role: .destructive) {
                                HapticManager.notificationOccurred(.warning)
                                showingLeaveLedgerAlert = true
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }
                            .accessibilityLabel("退出账本")
                        } else if currentLedger.ownerId == auth.user?.id {
                            Button(role: .destructive) {
                                HapticManager.notificationOccurred(.warning)
                                showingDeleteLedgerAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("删除账本")
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticManager.impact(.medium)
                            sheetType = .addLedger
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.spring(.light))
                        .accessibilityLabel("新建账本")
                    }
                }
            }
        }
        .environmentObject(auth)
        .environmentObject(ledgerStore)
    }

    /// Explicit pick when the user has multiple ledgers and no last-used selection.
    private var ledgerPickerView: some View {
        LedgerPickerBookshelf(
            searchText: searchText,
            onClearSearch: { searchText = "" }
        )
        .environmentObject(ledgerStore)
        .environmentObject(auth)
    }

    private func openLedgerDrawerFromMenuButton() {
        HapticManager.impact(.light)
        sheetType = .ledgerDrawer
    }

    private func openExpenseDetail(_ expense: Expense, in ledger: Ledger) {
        HapticManager.impact(.light)
        sheetType = .expenseDetail(expense, ledger)
    }

    private func copyExpenseTitle(_ expense: Expense) {
        UIPasteboard.general.string = expense.title
        HapticManager.notificationOccurred(.success)
    }

    private func copyExpenseAmount(_ expense: Expense) {
        UIPasteboard.general.string = formatAmount(expense.amount)
        HapticManager.notificationOccurred(.success)
    }

    private func prepareToDeleteExpense(_ expense: Expense, in ledger: Ledger) {
        HapticManager.impact(.light)
        expenseToDelete = expense
        expenseDeleteLedgerId = ledger.id
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("暂无账本", systemImage: "book.closed")
        } description: {
            Text("创建一个账本，邀请朋友一起分摊开销")
        } actions: {
            Button {
                HapticManager.impact(.medium)
                sheetType = .addLedger
            } label: {
                Text("创建第一个账本")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func filteredExpenses(for ledger: Ledger) -> [Expense] {
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
    }

    private func ledgerDetailView(_ ledger: Ledger) -> some View {
        List {
            Section {
                ledgerOverviewCard(ledger)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            expenseListSection(ledger)
            mySettlementSection(ledger)
            allSettlementsLinkSection(ledger)
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if loadedSettlementLedgerId != ledger.id {
                loadedSettlementLedgerId = ledger.id
                loadSettlementData(for: ledger)
            } else if settlementSuggestions.isEmpty {
                // Detail may already be on screen from cache; still fill settlements if missing.
                loadSettlementData(for: ledger)
            }
        }
        .onChange(of: ledger.id) { _, _ in
            loadedSettlementLedgerId = ledger.id
            settlementSuggestions = []
            loadSettlementData(for: ledger)
        }
    }

    @ViewBuilder
    private func expenseListSection(_ ledger: Ledger) -> some View {
        let expenses = filteredExpenses(for: ledger)
        Section {
            if ledger.expenses.isEmpty {
                if ledgerStore.isLoadingCurrentDetail {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else {
                    emptyExpensesPlaceholder
                }
            } else if expenses.isEmpty {
                noMatchingExpensesPlaceholder
            } else {
                ForEach(expenses) { expense in
                    expenseListRow(expense, ledger: ledger)
                }
            }
        } header: {
            expenseSectionHeader(count: expenses.count)
        }
    }

    private func expenseListRow(_ expense: Expense, ledger: Ledger) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ExpenseUnifiedListRow(expense: expense)
            if canRespond(to: expense, in: ledger) {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.impact(.rigid, intensity: 0.8)
                        respond(to: expense, with: .rejected, in: ledger)
                    } label: {
                        Label("拒绝", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(respondingExpenseIds.contains(expense.id))

                    Button {
                        HapticManager.impact(.medium, intensity: 0.9)
                        respond(to: expense, with: .confirmed, in: ledger)
                    } label: {
                        if respondingExpenseIds.contains(expense.id) {
                            ProgressView()
                        } else {
                            Text("确认")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(respondingExpenseIds.contains(expense.id))
                }
            }
        }
        .padding(.vertical, 2)
        .listRowAnimation()
        .contentShape(Rectangle())
        .onTapGesture {
            openExpenseDetail(expense, in: ledger)
        }
        .contextMenu {
            Button {
                openExpenseDetail(expense, in: ledger)
            } label: {
                Label("查看详情", systemImage: "info.circle")
            }

            Button {
                copyExpenseTitle(expense)
            } label: {
                Label("复制标题", systemImage: "doc.on.doc")
            }

            Button {
                copyExpenseAmount(expense)
            } label: {
                Label("复制金额", systemImage: "yensign.circle")
            }

            if canRespond(to: expense, in: ledger) {
                Divider()
                Button {
                    HapticManager.impact(.medium, intensity: 0.9)
                    respond(to: expense, with: .confirmed, in: ledger)
                } label: {
                    Label("确认账单", systemImage: "checkmark.circle")
                }
                Button(role: .destructive) {
                    HapticManager.impact(.rigid, intensity: 0.85)
                    respond(to: expense, with: .rejected, in: ledger)
                } label: {
                    Label("拒绝账单", systemImage: "xmark.circle")
                }
            }

            if canEditExpense(expense, in: ledger) {
                Divider()
                Button {
                    openEditExpense(expense, in: ledger)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
            }

            if expense.createdBy == auth.user?.id {
                Divider()
                Button(role: .destructive) {
                    prepareToDeleteExpense(expense, in: ledger)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if canRespond(to: expense, in: ledger) {
                Button {
                    HapticManager.impact(.medium, intensity: 0.95)
                    respond(to: expense, with: .confirmed, in: ledger)
                } label: {
                    Label("确认", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            } else if canEditExpense(expense, in: ledger) {
                Button {
                    openEditExpense(expense, in: ledger)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .tint(EvenlyStyle.brandBlue)
            }
        }
        .evenlyDestructiveSwipe(enabled: expense.createdBy == auth.user?.id) {
            prepareToDeleteExpense(expense, in: ledger)
        }
    }

    private var emptyExpensesPlaceholder: some View {
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
    }

    private var noMatchingExpensesPlaceholder: some View {
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
    }

    private func expenseSectionHeader(count: Int) -> some View {
        HStack {
            Text("账单（\(count)）")
            Spacer()
            Button {
                expenseFilter = expenseFilter.next
                HapticManager.selectionChanged()
            } label: {
                HStack(spacing: 4) {
                    Text(expenseFilter.rawValue)
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .font(.caption)
                .fontWeight(.medium)
            }
            .buttonStyle(.spring(.soft))
            .foregroundStyle(EvenlyStyle.brandBlue)
        }
        .textCase(nil)
    }

    @ViewBuilder
    private func mySettlementSection(_ ledger: Ledger) -> some View {
        let mine = mySettlements(in: ledger)
        // Avoid a full-width spinner when we already have bills/settlements on screen.
        let showBlockingSpinner = isLoadingSettlementData && mine.isEmpty && ledger.expenses.isEmpty
        if showBlockingSpinner || settlementError != nil || !mine.isEmpty {
            Section {
                if showBlockingSpinner {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let err = settlementError, mine.isEmpty {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    ForEach(mine) { settlement in
                        mySettlementRow(settlement)
                    }
                }
            } header: {
                Text("与我相关的转账流向")
            } footer: {
                Text(ledger.requireConfirmation
                     ? "转账按全部账单预估（含未确认）；未确认相关会灰色标记"
                     : "本账本未开启确认：记账后立即进入转账流向")
            }
        }
    }

    private func allSettlementsLinkSection(_ ledger: Ledger) -> some View {
        Section {
            NavigationLink {
                SettlementDetailView(
                    ledger: ledger,
                    suggestions: settlementSuggestions
                )
            } label: {
                HStack {
                    Label("查看全部转账流向", systemImage: "list.bullet.rectangle.portrait")
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

    private func ledgerOverviewCard(_ ledger: Ledger) -> some View {
        let total = ledger.expenses.reduce(Decimal.zero) { $0 + $1.netAmount }
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
                    presentLedgerShare(for: ledger)
                    HapticManager.impact(.light)
                } label: {
                    overviewAction(icon: "square.and.arrow.up", label: "分享")
                }
                .buttonStyle(.plain)
                Button {
                    sheetType = .members(ledger)
                    HapticManager.impact(.light)
                } label: {
                    overviewMetric(icon: "person.2.fill", value: "\(ledger.participantCount)", label: "成员")
                }
                .buttonStyle(.plain)
                Button {
                    sheetType = .addExpense
                    HapticManager.impact(.medium)
                } label: {
                    overviewAction(icon: "plus.circle.fill", label: "添加账单")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(overviewCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: EvenlyStyle.brandBlue.opacity(colorScheme == .dark ? 0.20 : 0.16), radius: 10, y: 5)
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }

    private func presentLedgerShare(for ledger: Ledger) {
        shareSnapshot = LedgerShareSnapshot.build(
            ledger: ledger,
            settlements: settlementSuggestions
        )
    }

    private var overviewCardBackground: some ShapeStyle {
        LinearGradient(
            colors: colorScheme == .dark
                ? [EvenlyStyle.brandBlueDeep.opacity(0.96), Color(red: 0.15, green: 0.29, blue: 0.48)]
                : [EvenlyStyle.brandBlueHero, EvenlyStyle.brandBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    private func overviewAction(icon: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
            Text(label)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.9))
        .frame(minWidth: 52)
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



    private func canRespond(to expense: Expense, in ledger: Ledger? = nil) -> Bool {
        let host = ledger
            ?? ledgerStore.currentLedger
            ?? ledgerStore.ledgers.first(where: { $0.expenses.contains(where: { $0.id == expense.id }) })
        guard let host, host.requireConfirmation else { return false }
        guard expense.status == .pending,
              let userId = auth.user?.id,
              // Creator and payer do not need to confirm.
              expense.createdBy != userId,
              expense.payer.userId != userId,
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
        // Stale-while-revalidate: only block the UI when there is nothing to show yet.
        let needsBlockingLoad = settlementSuggestions.isEmpty && ledger.expenses.isEmpty
        if needsBlockingLoad {
            isLoadingSettlementData = true
        }
        settlementError = nil
        ledgerStore.fetchOverview(for: ledger, force: false) { result in
            isLoadingSettlementData = false
            switch result {
            case .success(let overview):
                settlementSuggestions = overview.settlementSuggestions.map { Settlement(from: $0) }
            case .failure(let error):
                // Cancelled/debounced soft refresh is not a user-facing error.
                if (error as? URLError)?.code == .cancelled { return }
                if needsBlockingLoad {
                    settlementError = error.localizedDescription
                }
            }
        }
    }

    /// 与当前用户相关的转账流向:我需转给别人的 + 别人需转给我的
    /// 后端按 confirmed+pending 预估终局流向；含未确认的会带 includesUnconfirmed。
    private func mySettlements(in ledger: Ledger) -> [Settlement] {
        guard let me = auth.user?.id else { return [] }
        return settlementSuggestions.filter { suggestion in
            (suggestion.fromUserId == me || suggestion.toUserId == me) && suggestion.amount > 0
        }
    }

    @ViewBuilder
    private func mySettlementRow(_ settlement: Settlement) -> some View {
        let me = auth.user?.id
        let iOwe = settlement.fromUserId == me
        let provisional = settlement.includesUnconfirmed
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(provisional
                          ? Color.secondary.opacity(0.18)
                          : (iOwe ? Color.orange.opacity(0.2) : Color.green.opacity(0.2)))
                    .frame(width: 36, height: 36)
                Image(systemName: iOwe ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(provisional ? Color.secondary : (iOwe ? .orange : .green))
            }

            VStack(alignment: .leading, spacing: 2) {
                if iOwe {
                    Text("我需转给 \(settlement.toUserName)")
                        .font(.subheadline)
                        .foregroundStyle(provisional ? .secondary : .primary)
                } else {
                    Text("\(settlement.fromUserName) 需转给我")
                        .font(.subheadline)
                        .foregroundStyle(provisional ? .secondary : .primary)
                }
                if provisional {
                    Text("含未确认账单")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatAmount(settlement.amount))
                .font(.headline)
                .foregroundStyle(provisional ? Color.secondary : (iOwe ? .orange : .green))
        }
        .padding(.vertical, 2)
        .opacity(provisional ? 0.85 : 1)
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

    private func deleteCurrentLedger(_ ledger: Ledger) {
        ledgerStore.deleteLedger(ledger) { error in
            if let error {
                HapticManager.notificationOccurred(.error)
                actionError = error.localizedDescription
            } else {
                HapticManager.notificationOccurred(.success)
            }
        }
    }

    /// Net per member from **confirmed** expenses only (same rule as backend settlement).
    /// Positive = 应收, negative = 应付. Pending / rejected bills do not move balances.
    private func calculateBalanceResults(for ledger: Ledger) -> [BalanceResult] {
        var balances: [Person: Decimal] = [:]
        for participant in ledger.participants where participant.isActive {
            balances[participant] = 0
        }

        for expense in ledger.settlementExpenses {
            if expense.participants.isEmpty { continue }
            let net = expense.netAmount
            let share = net / Decimal(expense.participants.count)
            balances[expense.payer, default: 0] += net
            for participant in expense.participants {
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
