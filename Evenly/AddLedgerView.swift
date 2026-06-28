import SwiftUI

struct AddLedgerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var ledgerStore: LedgerStore
    @State private var title: String = ""
    @State private var participantInput: String = ""
    @State private var participants: [ParticipantInfo] = []
    @State private var errorMessage: String?
    @State private var searchResults: [UserResponse] = []
    @State private var isSearching = false
    @State private var completedSearchQuery = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSaveError = false
    @FocusState private var focusedField: Field?

    enum Field {
        case title
        case participant
    }

    var onSave: ((Ledger) -> Void)?
    private let existingLedger: Ledger?

    struct ParticipantInfo: Identifiable {
        let id = UUID()
        let name: String
        var status: Status
        var isLoading: Bool = false

        enum Status: Equatable {
            case idle
            case found(userId: String, name: String)
            case notFound
            case local
        }

        var person: Person {
            if case .found(let userId, _) = status {
                return Person(name: name, userId: userId)
            }
            return Person(name: name, isTemporary: true)
        }
    }

    static func filteredSearchResults(
        _ results: [UserResponse],
        excluding participants: [ParticipantInfo]
    ) -> [UserResponse] {
        let selectedUserIds = Set(participants.compactMap { participant -> String? in
            guard case .found(let userId, _) = participant.status else { return nil }
            return userId
        })
        return results.filter { !selectedUserIds.contains($0.id) }
    }

    init(ledger: Ledger? = nil, onSave: @escaping (Ledger) -> Void) {
        self.onSave = onSave
        self.existingLedger = ledger
        _title = State(initialValue: ledger?.title ?? "")
        _participants = State(initialValue: ledger?.participants.map { ParticipantInfo(name: $0.name, status: .local) } ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        
                        TextField("输入账本名称", text: $title)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .title)
                    }
                } header: {
                    Text("账本名称")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        
	                    TextField("输入邮箱或名字搜索", text: $participantInput)
	                        .textInputAutocapitalization(.never)
	                        .autocorrectionDisabled()
	                        .focused($focusedField, equals: .participant)

                        if isSearching {
                            ProgressView()
                        }
                    }

                    ForEach(searchResults) { user in
                        Button {
                            selectUser(user)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName ?? user.email.components(separatedBy: "@").first ?? "用户")
                                        .foregroundStyle(.primary)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if shouldOfferTemporaryMember {
                        Button {
                            addTemporaryParticipant()
                        } label: {
                            Label("将「\(trimmedParticipantInput)」添加为临时成员", systemImage: "person.crop.circle.badge.plus")
                                .foregroundStyle(.orange)
                        }
                    }

                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                        }
                    }
                } header: {
	                    Text("搜索成员")
	                } footer: {
	                    Text("搜索已注册用户，或添加临时成员")
	                }

                if !participants.isEmpty {
                    Section {
                        ForEach(participants) { participant in
                            participantRow(participant)
                                .listRowAnimation()
                        }
                    } header: {
                        Text("参与者 (\(participants.count))")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .task(id: participantInput) {
                await searchParticipants()
            }
            .navigationTitle(existingLedger == nil ? "新建账本" : "编辑账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.impact(.light)
                        dismiss()
                    } label: {
                        Text("取消")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveLedger()
                    } label: {
                        Text("保存")
                            .fontWeight(.semibold)
                    }
                    .disabled(!canSave || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .alert("保存失败", isPresented: $showSaveError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(saveError ?? "未知错误")
            }
        }
    }

    private func participantRow(_ participant: ParticipantInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor(for: participant.status).opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(String(participant.name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(statusColor(for: participant.status))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.body)
                
                HStack(spacing: 4) {
                    statusIcon(for: participant.status)
                    statusText(for: participant.status)
                }
                .font(.caption)
            }

            Spacer()

            Button(role: .destructive) {
                HapticManager.impact(.light)
                participants.removeAll { $0.id == participant.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: ParticipantInfo.Status) -> Color {
        switch status {
        case .idle:
            return .gray
        case .found:
            return .green
        case .notFound:
            return .orange
        case .local:
            return .blue
        }
    }

    private func statusIcon(for status: ParticipantInfo.Status) -> some View {
        switch status {
        case .idle:
            return Image(systemName: "person.fill")
        case .found:
            return Image(systemName: "checkmark.circle.fill")
        case .notFound:
            return Image(systemName: "exclamationmark.circle.fill")
        case .local:
            return Image(systemName: "person.fill")
        }
    }

    @ViewBuilder
    private func statusText(for status: ParticipantInfo.Status) -> some View {
        switch status {
        case .idle:
            Text("本地")
        case .found(_, let foundName):
            Text("@\(foundName)")
        case .notFound:
            Text("未注册")
        case .local:
            Text("本地")
        }
    }

    private var canSave: Bool {
        !title.isEmpty
    }

    private var trimmedParticipantInput: String {
        participantInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldOfferTemporaryMember: Bool {
        let query = trimmedParticipantInput
        return query.count >= 2
            && completedSearchQuery == query
            && searchResults.isEmpty
            && !participants.contains { $0.name.caseInsensitiveCompare(query) == .orderedSame }
    }

    @MainActor
    private func searchParticipants() async {
        let query = trimmedParticipantInput
        errorMessage = nil
        completedSearchQuery = ""
        searchResults = []

        guard query.count >= 2 else {
            isSearching = false
            return
        }

        isSearching = true
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            let users: [UserResponse] = try await APIClient.shared.get(APIEndpoints.searchUsers(q: query, limit: 5))
            try Task.checkCancellation()
            searchResults = Self.filteredSearchResults(users, excluding: participants)
            completedSearchQuery = query
            isSearching = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            isSearching = false
            completedSearchQuery = query
            errorMessage = error.localizedDescription
        }
    }

    private func selectUser(_ user: UserResponse) {
        let displayName = user.displayName ?? user.email.components(separatedBy: "@").first ?? "用户"
        participants.append(ParticipantInfo(name: displayName, status: .found(userId: user.id, name: displayName)))
        participantInput = ""
        searchResults = []
        completedSearchQuery = ""
        HapticManager.impact(.light)
    }

    private func addTemporaryParticipant() {
        participants.append(ParticipantInfo(name: trimmedParticipantInput, status: .local))
        participantInput = ""
        searchResults = []
        completedSearchQuery = ""
        HapticManager.impact(.light)
    }

    private func saveLedger() {
        guard canSave else { return }
        
        HapticManager.notificationOccurred(.success)

        isSaving = true

        let persons = participants.map(\.person)

        let ledger = Ledger(
            id: existingLedger?.id ?? UUID(),
            title: title,
            ownerId: auth.user?.id ?? "",
            memberIds: [],
            participants: persons,
            expenses: existingLedger?.expenses ?? []
        )

        if existingLedger != nil {
            // 编辑模式 - 暂时不更新
            onSave?(ledger)
            isSaving = false
            dismiss()
        } else {
            // 创建模式
            ledgerStore.createLedger(ledger) { result in
                DispatchQueue.main.async {
                    self.isSaving = false

                    switch result {
                    case .failure(let error):
                        self.saveError = error.localizedDescription
                        self.showSaveError = true
                        HapticManager.notificationOccurred(.error)
                    case .success(let createdLedger):
                        self.onSave?(createdLedger)
                        self.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddLedgerView { _ in }
        .environmentObject(AuthManager())
        .environmentObject(LedgerStore())
}
