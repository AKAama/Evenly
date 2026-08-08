import SwiftUI
import PhotosUI
import UIKit

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
    /// Default on for multi-person trust; owner can turn off anytime.
    @State private var requireConfirmation = true
    @State private var coverImage: UIImage?
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var isPickingCover = false
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
        var username: String? = nil
        var avatarUrl: String? = nil
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
        _requireConfirmation = State(initialValue: ledger?.requireConfirmation ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        
                        TextField("输入账本名称", text: $title)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .participant }
                    }
                    .id(Field.title)
                } header: {
                    Text("账本名称")
                }

                Section {
                    HStack(alignment: .center, spacing: 16) {
                        coverPreview
                            .frame(width: 72, height: 106)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(coverImage == nil ? "可选，会出现在账本列表封面" : "已选择封面")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $coverPickerItem, matching: .images) {
                                    Label(coverImage == nil ? "选择封面" : "更换", systemImage: "photo")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .tint(EvenlyStyle.brandBlue)

                                if coverImage != nil {
                                    Button("清除") {
                                        coverImage = nil
                                        coverPickerItem = nil
                                        HapticManager.selectionChanged()
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("封面")
                } footer: {
                    Text("不选则使用默认封面色；创建后可在账本列表长按修改。")
                }

                Section {
                    Toggle(isOn: $requireConfirmation) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("需要成员确认账单")
                            Text(requireConfirmation
                                 ? "参与人确认后，账单才会计入转账与分享"
                                 : "记账后立即计入转账与分享，无需确认")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(EvenlyStyle.brandBlue)
                } header: {
                    Text("结算规则")
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
	                        .submitLabel(.done)
	                        .onSubmit { focusedField = nil }

                        if isSearching {
                            ProgressView()
                        }
                    }
                    .id(Field.participant)

                    ForEach(searchResults) { user in
                        Button {
                            selectUser(user)
                        } label: {
                            HStack(spacing: 12) {
                                RemoteAvatarView(
                                    avatarUrl: user.avatarUrl,
                                    fallbackText: user.displayName ?? user.username,
                                    size: 36
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName ?? user.email.components(separatedBy: "@").first ?? "用户")
                                        .foregroundStyle(.primary)
                                    Text("@\(user.username)")
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
            .onChange(of: focusedField) { _, field in
                guard let field else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            .task(id: participantInput) {
                await searchParticipants()
            }
            .onChange(of: coverPickerItem) { _, item in
                guard let item else { return }
                Task { await loadCover(from: item) }
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
    }

    private func participantRow(_ participant: ParticipantInfo) -> some View {
        HStack(spacing: 12) {
            RemoteAvatarView(
                avatarUrl: participant.avatarUrl,
                fallbackText: participant.name,
                size: 40
            )
            
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
        case .found:
            Text("@\(participantUsername(for: status))")
        case .notFound:
            Text("未注册")
        case .local:
            Text("本地")
        }
    }

    private func participantUsername(for status: ParticipantInfo.Status) -> String {
        guard case .found(_, let username) = status else { return "" }
        return username
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
        participants.append(ParticipantInfo(
            name: displayName,
            username: user.username,
            avatarUrl: user.avatarUrl,
            status: .found(userId: user.id, name: user.username)
        ))
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
            expenses: existingLedger?.expenses ?? [],
            requireConfirmation: requireConfirmation
        )

        if existingLedger != nil {
            // 编辑模式 - 暂时不更新
            onSave?(ledger)
            isSaving = false
            dismiss()
        } else {
            // 创建模式：先建账本，再上传可选封面（同一 COS 接口）。
            ledgerStore.createLedger(ledger) { result in
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.saveError = error.localizedDescription
                        self.showSaveError = true
                        HapticManager.notificationOccurred(.error)
                    }
                case .success(let createdLedger):
                    self.uploadCoverIfNeeded(for: createdLedger)
                }
            }
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
        } else {
            // Preview default generated spine style (placeholder book).
            let palette = LedgerBookCoverStyle.colors(for: existingLedger?.id ?? UUID())
            ZStack {
                LinearGradient(
                    colors: [palette.0, palette.1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(title.isEmpty ? "封面" : String(title.prefix(4)))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
            }
        }
    }

    @MainActor
    private func loadCover(from item: PhotosPickerItem) async {
        isPickingCover = true
        defer { isPickingCover = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            coverImage = image
            HapticManager.impact(.light)
        } catch {
            saveError = "无法读取封面图片"
            showSaveError = true
        }
    }

    /// After create succeeds, push cover bytes if user picked one; always dismiss.
    private func uploadCoverIfNeeded(for created: Ledger) {
        guard let coverImage,
              let jpeg = LedgerCoverImagePrep.jpegData(from: coverImage) else {
            DispatchQueue.main.async {
                self.isSaving = false
                self.onSave?(created)
                HapticManager.notificationOccurred(.success)
                self.dismiss()
            }
            return
        }
        ledgerStore.uploadLedgerCover(created, imageData: jpeg) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(let withCover):
                    self.onSave?(withCover)
                    HapticManager.notificationOccurred(.success)
                case .failure:
                    // Ledger exists; cover is optional — still open it. User can long-press on shelf to retry.
                    self.onSave?(created)
                    HapticManager.notificationOccurred(.warning)
                }
                self.dismiss()
            }
        }
    }
}

#Preview {
    AddLedgerView { _ in }
        .environmentObject(AuthManager())
        .environmentObject(LedgerStore())
}
