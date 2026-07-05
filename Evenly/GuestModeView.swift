import SwiftUI
import Combine

@MainActor
final class GuestLedgerStore: ObservableObject {
    @Published private(set) var ledgers: [Ledger] = []
    @Published var currentLedgerId: UUID?

    private let storageKey = "Evenly.guestLedgers"
    private let selectedLedgerKey = "Evenly.guestCurrentLedgerId"

    init() {
        load()
    }

    var currentLedger: Ledger? {
        guard let currentLedgerId else { return ledgers.first }
        return ledgers.first { $0.id == currentLedgerId } ?? ledgers.first
    }

    func select(_ ledger: Ledger) {
        currentLedgerId = ledger.id
        UserDefaults.standard.set(ledger.id.uuidString, forKey: selectedLedgerKey)
    }

    func createLedger(title: String, memberNames: [String]) {
        let owner = Person(name: "我", isTemporary: true)
        let otherMembers = memberNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "我" }
            .uniqued()
            .map { Person(name: $0, isTemporary: true) }
        let participants = [owner] + otherMembers
        let ledger = Ledger(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerId: "guest",
            participants: participants,
            memberCount: participants.count
        )
        ledgers.append(ledger)
        select(ledger)
        save()
    }

    func addMember(name: String) {
        guard let index = currentIndex else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !ledgers[index].participants.contains(where: {
                  $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame
              }) else { return }
        ledgers[index].participants.append(Person(name: cleaned, isTemporary: true))
        ledgers[index].memberCount = ledgers[index].participants.count
        save()
    }

    func addExpense(
        title: String,
        amount: Decimal,
        payer: Person,
        participants: [Person]
    ) {
        guard let index = currentIndex, amount > 0, !participants.isEmpty else { return }
        let expense = Expense(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            payer: payer,
            participants: participants,
            status: .confirmed,
            expenseDate: Date()
        )
        ledgers[index].expenses.insert(expense, at: 0)
        ledgers[index].expenseCount = ledgers[index].expenses.count
        save()
    }

    func deleteExpenses(at offsets: IndexSet) {
        guard let index = currentIndex else { return }
        ledgers[index].expenses.remove(atOffsets: offsets)
        ledgers[index].expenseCount = ledgers[index].expenses.count
        save()
    }

    func deleteCurrentLedger() {
        guard let currentLedgerId else { return }
        ledgers.removeAll { $0.id == currentLedgerId }
        self.currentLedgerId = ledgers.first?.id
        save()
    }

    func balances(for ledger: Ledger) -> [(Person, Decimal)] {
        var balances = Dictionary(uniqueKeysWithValues: ledger.participants.map { ($0.id, Decimal.zero) })
        for expense in ledger.expenses where !expense.participants.isEmpty {
            let count = Decimal(expense.participants.count)
            let share = expense.amount / count
            balances[expense.payer.id, default: 0] += expense.amount
            for participant in expense.participants {
                balances[participant.id, default: 0] -= share
            }
        }
        return ledger.participants.map { ($0, balances[$0.id, default: 0]) }
    }

    private var currentIndex: Int? {
        guard let id = currentLedger?.id else { return nil }
        return ledgers.firstIndex { $0.id == id }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Ledger].self, from: data) {
            ledgers = decoded
        }
        currentLedgerId = UserDefaults.standard.string(forKey: selectedLedgerKey)
            .flatMap(UUID.init(uuidString:))
            ?? ledgers.first?.id
    }

    private func save() {
        if let data = try? JSONEncoder().encode(ledgers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        UserDefaults.standard.set(currentLedgerId?.uuidString, forKey: selectedLedgerKey)
    }
}

struct GuestModeView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var store = GuestLedgerStore()
    @State private var sheet: GuestSheet?
    @State private var showingDeleteLedger = false

    private enum GuestSheet: String, Identifiable {
        case addLedger
        case addMember
        case addExpense

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let ledger = store.currentLedger {
                    ledgerView(ledger)
                } else {
                    ContentUnavailableView {
                        Label("开始本地记账", systemImage: "iphone")
                    } description: {
                        Text("无需注册。账本仅保存在这台设备上。")
                    } actions: {
                        Button("创建本地账本") {
                            sheet = .addLedger
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(store.currentLedger?.title ?? "本地模式")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if !store.ledgers.isEmpty {
                            Section("本地账本") {
                                ForEach(store.ledgers) { ledger in
                                    Button {
                                        store.select(ledger)
                                    } label: {
                                        if ledger.id == store.currentLedger?.id {
                                            Label(ledger.title, systemImage: "checkmark")
                                        } else {
                                            Text(ledger.title)
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            sheet = .addLedger
                        } label: {
                            Label("新建本地账本", systemImage: "plus")
                        }

                        Button {
                            auth.leaveGuestMode()
                        } label: {
                            Label("登录或注册", systemImage: "person.crop.circle")
                        }

                        if store.currentLedger != nil {
                            Button(role: .destructive) {
                                showingDeleteLedger = true
                            } label: {
                                Label("删除当前账本", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            sheet = .addExpense
                        } label: {
                            Label("添加账单", systemImage: "plus.circle")
                        }

                        Button {
                            sheet = .addMember
                        } label: {
                            Label("添加成员", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(store.currentLedger == nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    Image(systemName: "iphone")
                    Text("本地模式 · 数据不会上传")
                    Spacer()
                    Button("登录同步") {
                        auth.leaveGuestMode()
                    }
                    .fontWeight(.semibold)
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.thinMaterial)
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .addLedger:
                GuestAddLedgerView { title, members in
                    store.createLedger(title: title, memberNames: members)
                }
            case .addMember:
                GuestAddMemberView { name in
                    store.addMember(name: name)
                }
            case .addExpense:
                if let ledger = store.currentLedger {
                    GuestAddExpenseView(ledger: ledger) { title, amount, payer, participants in
                        store.addExpense(
                            title: title,
                            amount: amount,
                            payer: payer,
                            participants: participants
                        )
                    }
                }
            }
        }
        .alert("删除本地账本？", isPresented: $showingDeleteLedger) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                store.deleteCurrentLedger()
            }
        } message: {
            Text("账本及其中的本地账单将从此设备永久删除。")
        }
    }

    private func ledgerView(_ ledger: Ledger) -> some View {
        List {
            Section {
                guestOverviewCard(ledger)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(store.balances(for: ledger), id: \.0.id) { person, balance in
                    HStack {
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(EvenlyStyle.blue)
                            .frame(width: 34, height: 34)
                            .background(EvenlyStyle.blue.opacity(0.11), in: Circle())
                        Text(person.name)
                            .fontWeight(.medium)
                        Spacer()
                        Text(balanceText(balance))
                            .foregroundStyle(balance > 0 ? .green : (balance < 0 ? .red : .secondary))
                    }
                }
            } header: {
                Text("成员余额")
            } footer: {
                Text("正数表示应收，负数表示应付。")
            }

            Section("账单") {
                if ledger.expenses.isEmpty {
                    Text("暂无账单，点击右上角添加。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ledger.expenses) { expense in
                        HStack(spacing: 13) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(EvenlyStyle.brandGradient, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 5) {
                                Text(expense.title)
                                    .font(.headline)
                                Text("\(expense.payer.name) 支付 · \(expense.participants.count) 人分摊")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(currency(expense.amount))
                                .font(.headline)
                        }
                        .padding(.vertical, 5)
                    }
                    .onDelete(perform: store.deleteExpenses)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private func guestOverviewCard(_ ledger: Ledger) -> some View {
        let total = ledger.expenses.reduce(Decimal.zero) { $0 + $1.amount }
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("仅保存在此设备", systemImage: "lock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                    Text(currency(total))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("本地累计支出")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.14), in: Circle())
            }

            HStack(spacing: 10) {
                guestMetric("\(ledger.participants.count)", label: "成员", icon: "person.2.fill")
                guestMetric("\(ledger.expenses.count)", label: "账单", icon: "receipt.fill")
            }
        }
        .padding(22)
        .background(EvenlyStyle.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: EvenlyStyle.indigo.opacity(0.24), radius: 18, y: 10)
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }

    private func guestMetric(_ value: String, label: String, icon: String) -> some View {
        Label("\(value) \(label)", systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.white.opacity(0.13), in: Capsule())
    }

    private func balanceText(_ value: Decimal) -> String {
        if value == 0 { return "已结清" }
        return "\(value > 0 ? "应收" : "应付") \(currency(abs(value)))"
    }

    private func currency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "¥0.00"
    }
}

private struct GuestAddLedgerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var members = ""
    let onSave: (String, [String]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("账本名称", text: $title)
                TextField("其他成员，用逗号分隔", text: $members)
                Section {
                    Text("“我”会自动加入账本。成员名称只保存在本机。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建本地账本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let names = members
                            .replacingOccurrences(of: "，", with: ",")
                            .split(separator: ",")
                            .map(String.init)
                        onSave(title, names)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct GuestAddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("成员名称", text: $name)
            }
            .navigationTitle("添加本地成员")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct GuestAddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    let ledger: Ledger
    let onSave: (String, Decimal, Person, [Person]) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var payerId: UUID
    @State private var participantIds: Set<UUID>
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case title
        case amount
    }

    init(
        ledger: Ledger,
        onSave: @escaping (String, Decimal, Person, [Person]) -> Void
    ) {
        self.ledger = ledger
        self.onSave = onSave
        let firstId = ledger.participants.first?.id ?? UUID()
        _payerId = State(initialValue: firstId)
        _participantIds = State(initialValue: Set(ledger.participants.map(\.id)))
    }

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账单") {
                    TextField("名称", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                }

                Section("付款人") {
                    Picker("付款人", selection: $payerId) {
                        ForEach(ledger.participants) { person in
                            Text(person.name).tag(person.id)
                        }
                    }
                    .onChange(of: payerId) { _, _ in focusedField = nil }
                }

                Section("参与分摊") {
                    ForEach(ledger.participants) { person in
                        Toggle(person.name, isOn: Binding(
                            get: { participantIds.contains(person.id) },
                            set: { included in
                                focusedField = nil
                                if included {
                                    participantIds.insert(person.id)
                                } else if person.id != payerId {
                                    participantIds.remove(person.id)
                                }
                            }
                        ))
                        .disabled(person.id == payerId)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("添加本地账单")
            .onChange(of: payerId) { _, newValue in
                participantIds.insert(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        focusedField = nil
                        guard let amount,
                              let payer = ledger.participants.first(where: { $0.id == payerId }) else { return }
                        let participants = ledger.participants.filter { participantIds.contains($0.id) }
                        onSave(title, amount, payer, participants)
                        dismiss()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || amount.map { $0 <= 0 } != false
                        || participantIds.isEmpty
                    )
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
