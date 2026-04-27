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
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var showAddTemporaryPrompt = false
    @State private var pendingEmailForTemporary: String = ""
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
                            .onSubmit {
                                addParticipant()
                            }

                        if isAddingParticipant {
                            ProgressView()
                        } else {
                            Button {
                                HapticManager.impact(.light)
                                addParticipant()
                            } label: {
                                Text("添加")
                                    .fontWeight(.medium)
                            }
                            .disabled(participantInput.isEmpty)
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
            .alert("添加为临时用户？", isPresented: $showAddTemporaryPrompt) {
                Button("添加") {
                    // 用户确认添加为临时用户
                    let participant = ParticipantInfo(name: pendingEmailForTemporary, status: .notFound, isLoading: false)
                    self.participants.append(participant)
                    self.participantInput = ""
                }
                Button("取消", role: .cancel) {
                    self.participantInput = ""
                    self.pendingEmailForTemporary = ""
                }
            } message: {
                Text("该邮箱 \(pendingEmailForTemporary) 未注册，是否添加为临时成员？")
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

                    if let user = users.first(where: { $0.email.lowercased() == email.lowercased() }) ?? users.first {
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
                        // 用户未注册，弹窗询问是否添加为临时用户
                        if self.participants.contains(where: { $0.name.lowercased() == email.lowercased() }) {
                            self.errorMessage = "该参与者已添加"
                        } else {
                            self.pendingEmailForTemporary = email
                            self.showAddTemporaryPrompt = true
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
        
        HapticManager.notificationOccurred(.success)

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
                DispatchQueue.main.async {
                    self.isSaving = false

                    if let error = error {
                        self.saveError = error.localizedDescription
                        self.showSaveError = true
                        HapticManager.notificationOccurred(.error)
                        return
                    }

                    // 保存成功，自动关闭页面
                    self.onSave?(ledger)
                    self.dismiss()
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
