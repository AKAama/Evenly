//
//  SettingsView.swift
//
//  Settings view with modern design
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                if let user = auth.user {
                    Section {
                        NavigationLink {
                            AccountSettingsView()
                                .environmentObject(auth)
                        } label: {
                            HStack(spacing: 16) {
                                RemoteAvatarView(
                                    avatarUrl: auth.userProfile?.avatarUrl,
                                    localImage: auth.avatarImage,
                                    fallbackText: auth.userProfile?.displayName ?? user.email,
                                    size: 60
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(auth.userProfile?.displayName ?? user.displayName ?? "用户")
                                        .font(.headline)
                                        .dynamicTypeSize(.accessibility2)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        Button(role: .destructive) {
                            HapticManager.notificationOccurred(.warning)
                            auth.signOut()
                        } label: {
                            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } header: {
                        Text("账户")
                    }
                }

                Section {
                    Picker("主题", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Label(theme.rawValue, systemImage: theme == .system ? "circle.lefthalf.filled" : (theme == .light ? "sun.max" : "moon"))
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: themeManager.currentTheme) { _, _ in
                        HapticManager.selection.selectionChanged()
                    }
                } header: {
                    Text("外观")
                } footer: {
                    Text("选择您喜欢的界面主题")
                }

                Section {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("导出与清除", systemImage: "square.and.arrow.up.on.square")
                    }
                } header: {
                    Text("数据")
                }

                Section {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        ChangelogView()
                    } label: {
                        Label("更新日志", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Link(destination: URL(string: "https://app.ismyh.cn/privacy/")!) {
                        Label("隐私政策", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://app.ismyh.cn/support/")!) {
                        Label("支持与反馈", systemImage: "questionmark.circle")
                    }
                    
                    HStack {
                        Spacer()
                        Text("© Alex_yehui")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } header: {
                    Text("关于")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
        }
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingChangePassword = false
    @State private var showingSetPassword = false
    @State private var showingChangeUsername = false
    @State private var showingChangeDisplayName = false
    @State private var showingChangeEmail = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    @State private var isUploadingAvatar = false
    @State private var showingDeleteAccountConfirmation = false

    var body: some View {
        List {
            if let user = auth.user {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            ZStack {
                                RemoteAvatarView(
                                    avatarUrl: auth.userProfile?.avatarUrl,
                                    localImage: selectedAvatarImage ?? auth.avatarImage,
                                    fallbackText: auth.userProfile?.displayName ?? user.email,
                                    size: 88
                                )
                                if isUploadingAvatar {
                                    Circle().fill(.black.opacity(0.35)).frame(width: 88, height: 88)
                                    ProgressView().tint(.white)
                                }
                            }
                        }
                        .disabled(isUploadingAvatar)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .onChange(of: avatarItem) { _, item in handleAvatarSelection(item) }
                }

                Section("账户信息") {
                    Button { showingChangeDisplayName = true } label: {
                        LabeledContent("显示名称", value: auth.userProfile?.displayName ?? user.displayName ?? "用户")
                    }
                    .foregroundStyle(.primary)

                    Button { showingChangeUsername = true } label: {
                        LabeledContent("用户名", value: "@\(user.username)")
                    }
                    .foregroundStyle(.primary)

                    if auth.hasPassword {
                        Button { showingChangeEmail = true } label: {
                            LabeledContent("邮箱", value: user.email)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        LabeledContent("Apple 登录邮箱", value: user.email)
                    }

                    Button {
                        if auth.hasPassword { showingChangePassword = true }
                        else { showingSetPassword = true }
                    } label: {
                        Label(
                            auth.hasPassword ? "修改密码" : "设置登录密码",
                            systemImage: auth.hasPassword ? "lock.rotation" : "lock.badge.plus"
                        )
                    }

                }

                Section {
                    Button(role: .destructive) {
                        HapticManager.notificationOccurred(.warning)
                        showingDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Label("删除账户", systemImage: "person.crop.circle.badge.minus")
                            Spacer()
                            if isLoading { ProgressView() }
                        }
                    }
                    .disabled(isLoading)
                } footer: {
                    Text("删除账户将永久删除个人资料、拥有的账本及关联记录，且无法恢复。")
                }
            }
        }
        .navigationTitle("账户设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChangePassword) { ChangePasswordView().environmentObject(auth) }
        .sheet(isPresented: $showingSetPassword) { SetPasswordView().environmentObject(auth) }
        .sheet(isPresented: $showingChangeUsername) { UsernameSetupView(required: false).environmentObject(auth) }
        .sheet(isPresented: $showingChangeDisplayName) { ChangeDisplayNameView().environmentObject(auth) }
        .sheet(isPresented: $showingChangeEmail) { ChangeEmailView().environmentObject(auth) }
        .alert(alertTitle, isPresented: $showingAlert) { Button("确定", role: .cancel) {} } message: { Text(alertMessage) }
        .alert("永久删除账户？", isPresented: $showingDeleteAccountConfirmation) {
            Button("取消", role: .cancel) {}
            Button("永久删除", role: .destructive) { deleteAccount() }
        } message: {
            Text("你的个人资料、拥有的账本、共享账本中的关联记录将被永久删除。此操作无法撤销。")
        }
        .onAppear { auth.refreshAuthMethods() }
    }

    private func handleAvatarSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isUploadingAvatar = true
        HapticManager.impact(.medium)
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let data, let image = UIImage(data: data) else {
                        isUploadingAvatar = false
                        showAlert(title: "上传失败", message: "无法读取所选图片")
                        return
                    }
                    selectedAvatarImage = image
                    uploadAvatar(image: image)
                case .failure:
                    isUploadingAvatar = false
                    showAlert(title: "上传失败", message: "图片加载失败,请重试")
                }
            }
        }
    }

    private func uploadAvatar(image: UIImage) {
        // 缩放到最长边 512,再压缩为 JPEG 控制体积
        let maxDimension: CGFloat = 512
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        let jpegData = scaled.jpegData(compressionQuality: 0.8) ?? Data()

        auth.updateAvatar(jpegData) { error in
            DispatchQueue.main.async {
                isUploadingAvatar = false
                avatarItem = nil
                if let error {
                    selectedAvatarImage = nil
                    showAlert(title: "上传失败", message: error.localizedDescription)
                } else {
                    selectedAvatarImage = auth.avatarImage
                    HapticManager.notificationOccurred(.success)
                    showAlert(title: "已更新", message: "头像更换成功")
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }

    private func deleteAccount() {
        isLoading = true
        auth.deleteAccount { error in
            isLoading = false
            if let error = error {
                alertTitle = "错误"
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}

struct UsernameSetupView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let required: Bool
    @State private var username = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("3–30 位，以英文字母开头，仅包含英文、数字和下划线。")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(required ? "设置你的用户名" : "修改用户名")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(required)
            .onAppear {
                username = auth.user?.usernameIsGenerated == true ? "" : auth.user?.username ?? ""
            }
            .toolbar {
                if !required {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") { save() }
                        .disabled(!auth.isValidUsername(username) || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        auth.updateUsername(username) { error in
            isSaving = false
            if let error {
                errorMessage = error.localizedDescription
                HapticManager.notificationOccurred(.error)
            } else {
                HapticManager.notificationOccurred(.success)
                dismiss()
            }
        }
    }
}

struct SetPasswordView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var codeSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("验证邮箱") {
                    Text(auth.user?.email ?? "")
                    Button(codeSent ? "重新发送验证码" : "发送验证码") { sendCode() }
                        .disabled(isLoading)
                }
                if codeSent {
                    Section("设置密码") {
                        TextField("邮箱验证码", text: $code).keyboardType(.numberPad)
                        SecureField("新密码", text: $newPassword).textContentType(.newPassword)
                        SecureField("再次输入新密码", text: $confirmPassword).textContentType(.newPassword)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("设置登录密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        codeSent && !code.isEmpty && newPassword.count >= 6 &&
        newPassword == confirmPassword && !isLoading
    }

    private func sendCode() {
        isLoading = true
        errorMessage = nil
        auth.sendPasswordSetupCode { error in
            isLoading = false
            if let error { errorMessage = error.localizedDescription }
            else { codeSent = true }
        }
    }

    private func save() {
        isLoading = true
        errorMessage = nil
        auth.setupPassword(code: code, newPassword: newPassword) { error in
            isLoading = false
            if let error {
                errorMessage = error.localizedDescription
                HapticManager.notificationOccurred(.error)
            } else {
                HapticManager.notificationOccurred(.success)
                dismiss()
            }
        }
    }
}

struct ChangeDisplayNameView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("显示名称", text: $displayName)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("显示名称用于账本和成员列表，可以与其他用户重复。")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("修改显示名称")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                displayName = auth.user?.displayName ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty || trimmedName.count > 100 || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        auth.updateDisplayName(trimmedName) { error in
            isSaving = false
            if let error {
                errorMessage = error.localizedDescription
                HapticManager.notificationOccurred(.error)
            } else {
                HapticManager.notificationOccurred(.success)
                dismiss()
            }
        }
    }
}

struct ChangeEmailView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var newEmail = ""
    @State private var code = ""
    @State private var password = ""
    @State private var codeSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("新邮箱") {
                    TextField("邮箱", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                if codeSent {
                    Section("验证") {
                        TextField("邮箱验证码", text: $code).keyboardType(.numberPad)
                        SecureField("当前密码", text: $password)
                    }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("换绑邮箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(codeSent ? "确认换绑" : "发送验证码") { submit() }
                        .disabled(!canSubmit || isLoading)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard auth.isValidEmail(newEmail) else { return false }
        return !codeSent || (!code.isEmpty && !password.isEmpty)
    }

    private func submit() {
        isLoading = true
        errorMessage = nil
        if codeSent {
            auth.changeEmail(newEmail: newEmail, code: code, password: password) { error in
                isLoading = false
                if let error { errorMessage = error.localizedDescription }
                else { dismiss() }
            }
        } else {
            auth.sendEmailChangeCode(newEmail: newEmail) { error in
                isLoading = false
                if let error { errorMessage = error.localizedDescription }
                else { codeSent = true }
            }
        }
    }
}

struct ChangePasswordView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var canSubmit: Bool {
        !oldPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword &&
        !isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("当前密码") {
                    SecureField("输入当前密码", text: $oldPassword)
                        .textContentType(.password)
                }

                Section("新密码") {
                    SecureField("输入新密码", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("再次输入新密码", text: $confirmPassword)
                        .textContentType(.newPassword)

                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("两次输入的新密码不一致")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if !newPassword.isEmpty && newPassword.count < 6 {
                        Text("新密码至少 6 位")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private func submit() {
        isLoading = true
        errorMessage = nil

        auth.changePassword(oldPassword: oldPassword, newPassword: newPassword) { error in
            isLoading = false
            if let error {
                HapticManager.notificationOccurred(.error)
                errorMessage = error.localizedDescription
            } else {
                HapticManager.notificationOccurred(.success)
                dismiss()
            }
        }
    }
}

struct ReauthenticateView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    let onSuccess: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("请重新输入密码以确认身份") {
                    TextField("邮箱", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    SecureField("密码", text: $password)
                        .textContentType(.password)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        reauthenticate()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("确认")
                            }
                            Spacer()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationTitle("验证身份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let userEmail = auth.user?.email {
                    email = userEmail
                }
            }
        }
    }

    private func reauthenticate() {
        isLoading = true
        errorMessage = ""
        auth.reauthenticate(email: email, password: password) { error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                dismiss()
                onSuccess()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(ThemeManager())
}
