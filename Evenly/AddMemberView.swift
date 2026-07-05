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
    @Environment(\.dismiss) var dismiss
    let ledgerId: UUID

    private var ledger: Ledger {
        ledgerStore.ledger(id: ledgerId)
            ?? Ledger(id: ledgerId, title: "", ownerId: "")
    }

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var memberToDelete: Person?
    
    // Search result
    @State private var searchResult: UserSearchResult?
    @State private var isSearching = false
    @State private var showingAddTemporary = false
    @State private var temporaryName = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case search
        case temporaryName
    }

    var body: some View {
        NavigationStack {
            List {
                // Search Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        
                        TextField("输入邮箱或名字搜索", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .search)
                            .onSubmit {
                                searchUser()
                            }
                    }
                    .padding(.vertical, 4)

                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let result = searchResult {
                        searchResultView(result)
                    }

                    Button {
                        HapticManager.impact(.medium)
                        searchUser()
                    } label: {
                        HStack {
                            Spacer()
                            Label("搜索用户", systemImage: "magnifyingglass")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .disabled(searchText.isEmpty || isLoading || isSearching)
                } header: {
                    Text("搜索成员")
                } footer: {
                    Text("搜索已注册用户，或添加临时成员")
                }

                // Add Temporary Member Section
                Section {
                    Button {
                        showingAddTemporary = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(.orange)
                            Text("添加临时成员")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("非注册用户")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("或")
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                        }
                    }
                }

                if let success = successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(success)
                                .font(.subheadline)
                        }
                    }
                }

                // Current Members Section
                Section {
                    ForEach(ledger.participants) { participant in
                        memberRowView(participant)
                            .listRowAnimation()
                    }
                } header: {
                    Text("当前成员 (\(ledger.participants.count))")
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("成员管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.impact(.light)
                        dismiss()
                    } label: {
                        Text("完成")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
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
	                                .focused($focusedField, equals: .temporaryName)
                        } header: {
                            Text("临时成员名字")
                        } footer: {
                            Text("临时成员会保存到当前账本，但无法登录系统")
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
                            .disabled(temporaryName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                HapticManager.prepare()
            }
        }
    }
    
    private func memberRowView(_ participant: Person) -> some View {
        HStack(spacing: 12) {
            memberAvatar(for: participant)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.body)
                    .dynamicTypeSize(.accessibility2)
                
                if participant.userId != nil {
                    Text("已注册用户")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("本地成员")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                HapticManager.notificationOccurred(.warning)
                deleteMember(participant)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func memberAvatar(for participant: Person) -> some View {
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
    }

    private func memberRecord(for participant: Person) -> MemberResponse? {
        ledger.members?.first { member in
            member.id == participant.id.uuidString
                || (participant.userId != nil && member.userId == participant.userId)
        }
    }

    @ViewBuilder
    private func searchResultView(_ result: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            // Avatar
            RemoteAvatarView(
                avatarUrl: result.found ? result.avatarUrl : nil,
                fallbackText: result.displayName ?? result.email,
                size: 44
            )
            
            VStack(alignment: .leading, spacing: 2) {
                if result.found {
                    Text(result.displayName ?? result.email)
                        .font(.body)
                        .lineLimit(1)
                    Text(result.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("已注册用户")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("未找到「\(result.query)」")
                        .font(.body)
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("可添加为临时成员")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if result.found, let userId = result.userId {
                addRegisteredMember(
                    userId: userId,
                    displayName: result.displayName ?? result.email.components(separatedBy: "@").first
                )
            } else if !result.found {
                // 未找到用户时，弹窗询问是否添加为临时成员
                temporaryName = result.email
                showingAddTemporary = true
            }
        }
    }

    private func searchUser() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        searchResult = nil

        // Search for user by email
        Task {
            do {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                        // User not found - offer to add as temporary
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
                    // User not found - offer to add as temporary
                    searchResult = UserSearchResult(
                        query: searchText,
                        found: false,
                        userId: nil,
                        email: searchText,
                        displayName: nil,
                        avatarUrl: nil
                    )
                }
            }
        }
    }

    private func addRegisteredMember(userId: String, displayName: String?) {
        isLoading = true
        errorMessage = nil

        ledgerStore.addMember(userId: userId, nickname: displayName, to: ledger) { result in
            isLoading = false

            switch result {
            case .success:
                successMessage = "邀请已发送，等待对方接受"
                searchResult = nil
                searchText = ""
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
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
}
