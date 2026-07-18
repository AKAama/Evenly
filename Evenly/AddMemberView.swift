//
//  AddMemberView.swift
//  Evenly
//
//  Created by alex_yehui on 2025/12/14.
//  Modern member management with animations and haptics
//

import SwiftUI

struct AddMemberView: View {
    @EnvironmentObject var ledgerStore: LedgerStore
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    let ledgerId: UUID

    private var ledger: Ledger {
        ledgerStore.ledger(id: ledgerId)
            ?? Ledger(id: ledgerId, title: "", ownerId: "")
    }

    private var currentParticipants: [Person] {
        ledger.participants.filter { !$0.isRemoved }
    }

    private var isOwner: Bool {
        auth.user?.id == ledger.ownerId
    }

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var memberToDelete: Person?
    @State private var showingAddTemporary = false
    @State private var temporaryName = ""
    @State private var showingInviteQR = false
    @State private var showingInviteSearch = false
    @State private var requireConfirmation = true
    @State private var isSavingConfirmationSetting = false
    @State private var confirmationSettingError: String?
    @FocusState private var temporaryNameFocused: Bool

    private var activeMembers: [Person] {
        currentParticipants.filter { !$0.isPending && !$0.isRejected }
    }

    private var pendingOrRejected: [Person] {
        currentParticipants.filter { $0.isPending || $0.isRejected }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                if let success = successMessage {
                    Section {
                        Label(success, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    if isOwner {
                        Toggle(isOn: Binding(
                            get: { requireConfirmation },
                            set: { applyRequireConfirmation($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("需要成员确认账单")
                                Text(requireConfirmation
                                     ? "参与人确认后才计入转账与分享"
                                     : "记账后立即计入转账与分享")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(EvenlyStyle.brandBlue)
                        .disabled(isSavingConfirmationSetting)
                        if isSavingConfirmationSetting {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("保存中…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let confirmationSettingError {
                            Text(confirmationSettingError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        HStack {
                            Text("账单确认")
                            Spacer()
                            Text(ledger.requireConfirmation ? "已开启" : "已关闭")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("结算规则")
                } footer: {
                    Text(isOwner
                         ? "关闭后，当前待确认账单会立刻生效并进入转账流向。"
                         : (ledger.requireConfirmation
                            ? "本账本需成员确认账单后才计入转账与分享。"
                            : "本账本记账后立即计入转账与分享，无需确认。"))
                }

                // Primary: who is in this ledger
                Section {
                    if activeMembers.isEmpty {
                        ContentUnavailableView(
                            "还没有成员",
                            systemImage: "person.2",
                            description: Text(isOwner ? "点右上角「邀请」把朋友加进来" : "等待账本创建者邀请成员")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(activeMembers) { participant in
                            memberRowView(participant)
                                .listRowAnimation()
                        }
                    }
                } header: {
                    Text("成员 (\(activeMembers.count))")
                }

                // Secondary: outstanding invites — only when relevant
                if !pendingOrRejected.isEmpty {
                    Section {
                        ForEach(pendingOrRejected) { participant in
                            memberRowView(participant)
                                .listRowAnimation()
                        }
                    } header: {
                        Text("邀请中 / 已拒绝 (\(pendingOrRejected.count))")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("成员")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { requireConfirmation = ledger.requireConfirmation }
            .onChange(of: ledger.requireConfirmation) { _, newValue in
                requireConfirmation = newValue
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.impact(.light)
                        dismiss()
                    } label: {
                        Text("完成")
                    }
                }
                if isOwner {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                HapticManager.impact(.medium)
                                showingInviteQR = true
                            } label: {
                                Label("二维码邀请", systemImage: "qrcode")
                            }
                            Button {
                                HapticManager.impact(.medium)
                                showingInviteSearch = true
                            } label: {
                                Label("搜索用户邀请", systemImage: "person.badge.plus")
                            }
                            Button {
                                HapticManager.impact(.medium)
                                showingAddTemporary = true
                            } label: {
                                Label("添加临时成员", systemImage: "person.crop.circle.badge.plus")
                            }
                        } label: {
                            Label("邀请", systemImage: "plus")
                        }
                        .accessibilityLabel("邀请成员")
                    }
                }
            }
            .sheet(isPresented: $showingInviteQR) {
                LedgerInviteQRView(ledgerId: ledgerId)
                    .environmentObject(ledgerStore)
            }
            .sheet(isPresented: $showingInviteSearch) {
                InviteBySearchSheet(
                    isLoading: $isLoading,
                    onInvite: { userId, displayName in
                        addRegisteredMember(userId: userId, displayName: displayName) {
                            showingInviteSearch = false
                        }
                    },
                    onOfferTemporary: { name in
                        temporaryName = name
                        showingInviteSearch = false
                        showingAddTemporary = true
                    }
                )
            }
            .confirmationDialog("确认删除", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let member = memberToDelete {
                        deleteMember(member)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要删除成员 \"\(memberToDelete?.name ?? "")\" 吗？")
            }
            .sheet(isPresented: $showingAddTemporary) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("输入成员名字", text: $temporaryName)
                                .focused($temporaryNameFocused)
                        } header: {
                            Text("临时成员名字")
                        } footer: {
                            Text("临时成员会保存在当前账本，但无法登录系统。适合当面分摊、对方暂无账号的情况。")
                        }
                    }
                    .navigationTitle("添加临时成员")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingAddTemporary = false
                                temporaryName = ""
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("添加") {
                                addTemporaryMember()
                            }
                            .disabled(temporaryName.isEmpty || isLoading)
                        }
                    }
                    .onAppear { temporaryNameFocused = true }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                HapticManager.prepare()
            }
            .onChange(of: successMessage) { _, value in
                guard value != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    if successMessage == value { successMessage = nil }
                }
            }
        }
    }

    private func applyRequireConfirmation(_ enabled: Bool) {
        guard enabled != requireConfirmation else { return }
        let previous = requireConfirmation
        requireConfirmation = enabled
        isSavingConfirmationSetting = true
        confirmationSettingError = nil
        ledgerStore.updateLedgerSettings(ledger, requireConfirmation: enabled) { result in
            isSavingConfirmationSetting = false
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
                successMessage = enabled ? "已开启账单确认" : "已关闭账单确认，待确认账单已生效"
                ledgerStore.fetchOverview(for: ledger, force: true) { _ in }
            case .failure(let error):
                requireConfirmation = previous
                confirmationSettingError = error.localizedDescription
                HapticManager.notificationOccurred(.error)
            }
        }
    }
    
    private func memberRowView(_ participant: Person) -> some View {
        HStack(spacing: 12) {
            memberAvatar(for: participant)
                .opacity((participant.isPending || participant.isRejected) ? 0.55 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(participant.name)
                        .font(.body)
                        .dynamicTypeSize(.accessibility2)
                        .foregroundStyle((participant.isPending || participant.isRejected) ? .secondary : .primary)
                    if let user = memberRecord(for: participant)?.user {
                        UserBadgeChip(key: user.badge, label: user.badgeLabel, colorName: user.badgeColor)
                    }
                    if participant.isPending {
                        Text("邀请中")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    } else if participant.isRejected {
                        Text("已拒绝")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(memberSubtitle(for: participant))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if auth.user?.id == ledger.ownerId, participant.userId != ledger.ownerId {
                if participant.isRejected {
                    Button {
                        HapticManager.impact(.light)
                        reinviteMember(participant)
                    } label: {
                        Text("再次邀请")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .disabled(isLoading)
                } else {
                    Button(role: .destructive) {
                        HapticManager.notificationOccurred(.warning)
                        deleteMember(participant)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func memberAvatar(for participant: Person) -> some View {
        let isOwner = participant.userId != nil && participant.userId == ledger.ownerId
        ZStack(alignment: .topTrailing) {
            if participant.isTemporary {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.16))
                    Image(systemName: "person.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                .frame(width: 40, height: 40)
            } else {
                RemoteAvatarView(
                    avatarUrl: memberRecord(for: participant)?.user?.avatarUrl,
                    fallbackText: participant.name,
                    size: 40
                )
            }

            if isOwner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(3)
                    .background(Circle().fill(Color(.systemBackground)))
                    .overlay(Circle().stroke(Color.orange.opacity(0.35), lineWidth: 0.8))
                    .offset(x: 4, y: -4)
                    .accessibilityLabel("账本创建者")
            }
        }
    }

    private func memberRecord(for participant: Person) -> MemberResponse? {
        ledger.members?.first { member in
            member.id == participant.id.uuidString
                || (participant.userId != nil && member.userId == participant.userId)
        }
    }

    private func memberSubtitle(for participant: Person) -> String {
        if participant.userId == ledger.ownerId { return "账本创建者" }
        if participant.isPending { return "等待对方接受" }
        if participant.isRejected { return "已拒绝，可再次邀请" }
        if participant.isTemporary { return "临时成员" }
        return "成员"
    }

    private func addRegisteredMember(userId: String, displayName: String?, onSuccess: (() -> Void)? = nil) {
        isLoading = true
        errorMessage = nil

        ledgerStore.addMember(userId: userId, nickname: displayName, to: ledger) { result in
            isLoading = false

            switch result {
            case .success:
                successMessage = "邀请已发送，等待对方接受"
                onSuccess?()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reinviteMember(_ participant: Person) {
        guard let userId = participant.userId else { return }
        addRegisteredMember(userId: userId, displayName: participant.name)
    }

    private func addTemporaryMember() {
        guard !temporaryName.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        // Add temporary member via API
        Task {
            do {
                let addRequest = AddMemberRequest(
                    userId: nil,
                    nickname: temporaryName,
                    isTemporary: true,
                    temporaryName: temporaryName
                )
                let _: MemberResponse = try await APIClient.shared.post(
                    APIEndpoints.addMember(ledgerId: ledger.id.uuidString),
                    body: addRequest
                )

                // Fetch updated ledger
                let response: LedgerWithMembers = try await APIClient.shared.get(
                    APIEndpoints.ledger(id: ledger.id.uuidString)
                )
                let updatedLedger = Ledger(from: response)

	                await MainActor.run {
	                    isLoading = false

	                    self.ledgerStore.applyUpdatedLedger(updatedLedger)

	                    successMessage = "临时成员添加成功！"
                    temporaryName = ""
                    showingAddTemporary = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteMember(_ member: Person) {
        let memberIdentifier = member.userId ?? member.id.uuidString
        ledgerStore.removeMember(memberIdentifier, from: ledger) { result in
            switch result {
            case .success:
                successMessage = "成员已删除"
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct UserSearchResult {
    let query: String
    let found: Bool
    let userId: String?
    let email: String
    let displayName: String?
    let avatarUrl: String?
}

// MARK: - Invite by search (owner-only sheet; keeps roster page clean)

private struct InviteBySearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isLoading: Bool
    var onInvite: (String, String?) -> Void
    var onOfferTemporary: (String) -> Void

    @State private var searchText = ""
    @State private var searchResult: UserSearchResult?
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("邮箱或用户名", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .onSubmit { searchUser() }
                    }
                    Button {
                        HapticManager.impact(.medium)
                        searchUser()
                    } label: {
                        if isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("搜索")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching || isLoading)
                } header: {
                    Text("查找用户")
                } footer: {
                    Text("找到后发送邀请；找不到可改为临时成员。")
                }

                if let result = searchResult {
                    Section {
                        searchResultRow(result)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("搜索邀请")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { searchFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func searchResultRow(_ result: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            RemoteAvatarView(
                avatarUrl: result.found ? result.avatarUrl : nil,
                fallbackText: result.displayName ?? result.email,
                size: 44
            )
            VStack(alignment: .leading, spacing: 2) {
                if result.found {
                    Text(result.displayName ?? result.email)
                        .font(.body.weight(.medium))
                    Text(result.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("未找到「\(result.query)」")
                        .font(.body)
                    Text("可添加为临时成员")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if result.found {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(EvenlyStyle.brandBlue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.impact(.medium)
            if result.found, let userId = result.userId {
                onInvite(
                    userId,
                    result.displayName ?? result.email.components(separatedBy: "@").first
                )
            } else {
                onOfferTemporary(result.query)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(result.found ? "邀请 \(result.displayName ?? result.email)" : "添加临时成员")
    }

    private func searchUser() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        searchResult = nil
        Task {
            do {
                let users: [UserResponse] = try await APIClient.shared.get(APIEndpoints.searchUsers(q: query))
                await MainActor.run {
                    isSearching = false
                    if let user = users.first(where: { $0.email.lowercased() == query.lowercased() }) ?? users.first {
                        searchResult = UserSearchResult(
                            query: query,
                            found: true,
                            userId: user.id,
                            email: user.email,
                            displayName: user.displayName,
                            avatarUrl: user.avatarUrl
                        )
                    } else {
                        searchResult = UserSearchResult(
                            query: query,
                            found: false,
                            userId: nil,
                            email: query,
                            displayName: nil,
                            avatarUrl: nil
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchResult = UserSearchResult(
                        query: query,
                        found: false,
                        userId: nil,
                        email: query,
                        displayName: nil,
                        avatarUrl: nil
                    )
                }
            }
        }
    }
}

struct MemberRowView: View {
    @EnvironmentObject var ledgerStore: LedgerStore
    let memberId: String
    let ledger: Ledger

    @State private var memberName: String = "加载中..."
    @State private var isRemoving = false
    @State private var isTemporary = false
    @State private var avatarUrl: String?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with status
            avatarView
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(memberName)
                        .font(.body)
                        .lineLimit(1)
                    
                    if isTemporary {
                        Text("临时")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 4) {
                    if ledger.ownerId == memberId {
                        Text("所有者")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else if isTemporary {
                        Text("临时成员")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("成员")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isRemoving {
                ProgressView()
            } else {
                if ledger.ownerId != memberId {
                    Button(role: .destructive) {
                        removeMember()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            fetchMemberInfo()
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if isTemporary {
            fallbackAvatar
        } else {
            RemoteAvatarView(avatarUrl: avatarUrl, fallbackText: memberName, size: 40)
        }
    }
    
    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(isTemporary ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
            
            if isTemporary {
                Image(systemName: "person.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                Text(String((memberName == "加载中..." ? "?" : memberName).prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fetchMemberInfo() {
        // Get member info from ledger's members
        if let member = ledger.members?.first(where: { $0.userId == memberId }) {
            memberName = member.nickname ?? member.temporaryName ?? member.user?.displayName ?? member.user?.email ?? "用户"
            isTemporary = member.isTemporary
            avatarUrl = member.user?.avatarUrl
        } else if memberId == ledger.ownerId {
            // Owner
            memberName = "所有者"
            isTemporary = false
        } else {
            memberName = "未知用户"
        }
    }

    private func removeMember() {
        isRemoving = true
        ledgerStore.removeMember(memberId, from: ledger) { result in
            isRemoving = false
        }
    }
}

#Preview {
    AddMemberView(ledgerId: UUID())
    .environmentObject(LedgerStore())
    .environmentObject(AuthManager())
}
