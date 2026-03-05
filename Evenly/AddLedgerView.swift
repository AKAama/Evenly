import SwiftUI

struct AddLedgerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var ledgerStore: LedgerStore
    @State private var title: String = ""
    @State private var participantInput: String = ""
    @State private var participants: [ParticipantInfo] = []
    @State private var errorMessage: String?
    @State private var isAddingParticipant = false
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var saveError: String?

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
                Section("账本名称") {
                    TextField("输入账本名称", text: $title)
                }

                Section("添加参与者") {
                    HStack {
                        TextField("邮箱 / 用户名", text: $participantInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                addParticipant()
                            }

                        if isAddingParticipant {
                            ProgressView()
                        } else {
                            Button("添加") {
                                addParticipant()
                            }
                            .disabled(participantInput.isEmpty)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if !participants.isEmpty {
                    Section("参与者 (\(participants.count))") {
                        ForEach(participants) { participant in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(participant.name)
                                        .font(.body)
                                    if case .found(_, let foundName) = participant.status {
                                        Text("@\(foundName)")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    } else if participant.status == .notFound {
                                        Text("未注册")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    participants.removeAll { $0.id == participant.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingLedger == nil ? "新建账本" : "编辑账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveLedger()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("保存成功", isPresented: $saveSuccess) {
                Button("确定") {
                    dismiss()
                }
            }
        }
    }

    private var canSave: Bool {
        !title.isEmpty
    }

    private func addParticipant() {
        let input = participantInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        errorMessage = nil

        if auth.isValidEmail(input) {
            checkUserExistsByEmail(input)
        } else {
            // 本地参与者：检查名字是否重复
            if participants.contains(where: { $0.name.lowercased() == input.lowercased() }) {
                errorMessage = "该参与者已添加"
                return
            }
            let participant = ParticipantInfo(name: input, status: .local)
            participants.append(participant)
            participantInput = ""
        }
    }

    private func checkUserExistsByEmail(_ email: String) {
        isAddingParticipant = true

        Task {
            do {
                let users: [UserResponse] = try await APIClient.shared.get(APIEndpoints.searchUsers(q: email))

                await MainActor.run {
                    self.isAddingParticipant = false
                    self.participantInput = ""

                    if let user = users.first(where: { $0.email.lowercased() == email.lowercased() }) {
                        let displayName = user.displayName ?? user.email.components(separatedBy: "@").first ?? "用户"

                        // 检查该用户是否已添加
                        if self.isUserAlreadyAdded(userId: user.id) {
                            self.errorMessage = "该用户已添加 (\(displayName))"
                        } else {
                            let participant = ParticipantInfo(
                                name: displayName,
                                status: .found(userId: user.id, name: displayName),
                                isLoading: false
                            )
                            self.participants.append(participant)
                        }
                    } else {
                        // 用户未注册，添加为本地参与者
                        if self.participants.contains(where: { $0.name.lowercased() == email.lowercased() }) {
                            self.errorMessage = "该参与者已添加"
                        } else {
                            let participant = ParticipantInfo(name: email, status: .notFound, isLoading: false)
                            self.participants.append(participant)
                            self.errorMessage = "该邮箱未注册，将作为本地参与者"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAddingParticipant = false
                    self.errorMessage = "查询失败，请重试"
                }
            }
        }
    }

    private func isUserAlreadyAdded(userId: String) -> Bool {
        participants.contains { participant in
            if case .found(let existingUserId, _) = participant.status {
                return existingUserId == userId
            }
            return false
        }
    }

    private func saveLedger() {
        guard canSave else { return }

        isSaving = true

        // 转换为 Person 数组
        let persons = participants.map { participant -> Person in
            if case .found(let userId, _) = participant.status {
                return Person(name: participant.name, userId: userId)
            } else {
                return Person(name: participant.name, userId: nil)
            }
        }

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
            ledgerStore.createLedger(ledger) { error in
                isSaving = false

                if let error = error {
                    saveError = error.localizedDescription
                    return
                }

                saveSuccess = true
                onSave?(ledger)
            }
        }
    }
}

#Preview {
    AddLedgerView { _ in }
        .environmentObject(AuthManager())
        .environmentObject(LedgerStore())
}
