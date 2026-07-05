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
    @State private var showingResetPasswordAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingChangePassword = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    @State private var isUploadingAvatar = false
    @State private var showingDeleteAccountConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if let user = auth.user {
                    Section {
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $avatarItem, matching: .images) {
                                ZStack {
                                    RemoteAvatarView(
                                        avatarUrl: auth.userProfile?.avatarUrl,
                                        localImage: selectedAvatarImage ?? auth.avatarImage,
                                        fallbackText: auth.userProfile?.displayName ?? user.email,
                                        size: 60
                                    )
                                    if isUploadingAvatar {
                                        Circle()
                                            .fill(.black.opacity(0.35))
                                            .frame(width: 60, height: 60)
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                            }
                            .disabled(isUploadingAvatar)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(auth.userProfile?.displayName ?? user.displayName ?? "用户")
                                    .font(.headline)
                                    .dynamicTypeSize(.accessibility2)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(isUploadingAvatar ? "上传中..." : "点击更换头像")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .onChange(of: avatarItem) { _, newItem in
                            handleAvatarSelection(newItem)
                        }
                        
                        HStack {
                            Label("邮箱", systemImage: "envelope")
                            Spacer()
                            Text(user.email)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            HapticManager.impact(.medium)
                            showingChangePassword = true
                        } label: {
                            Label("修改密码", systemImage: "lock.rotation")
                        }
                        .disabled(isLoading)

                        Button(role: .destructive) {
                            HapticManager.notificationOccurred(.warning)
                            showingDeleteAccountConfirmation = true
                        } label: {
                            HStack {
                                Label("删除账户", systemImage: "person.crop.circle.badge.minus")
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isLoading)
                    } header: {
                        Text("账户")
                    } footer: {
                        Text("删除账户将永久删除个人资料、拥有的账本及关联记录，且无法恢复。")
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
                    Button(role: .destructive) {
                        HapticManager.notificationOccurred(.warning)
                        auth.signOut()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
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
            .alert(alertTitle, isPresented: $showingResetPasswordAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
                    .environmentObject(auth)
            }
            .alert("永久删除账户？", isPresented: $showingDeleteAccountConfirmation) {
                Button("取消", role: .cancel) {}
                Button("永久删除", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("你的个人资料、拥有的账本、共享账本中的关联记录将被永久删除。此操作无法撤销。")
            }
        }
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
        showingResetPasswordAlert = true
    }

    private func showUnsupportedFeature(_ message: String) {
        alertTitle = "暂未支持"
        alertMessage = message
        showingResetPasswordAlert = true
    }

    private func resetPassword() {
        guard let user = auth.user else { return }
        let email = user.email
        isLoading = true
        auth.resetPassword(email: email) { error in
            isLoading = false
            if let error = error {
                alertTitle = "错误"
                alertMessage = error.localizedDescription
            } else {
                alertTitle = "重置邮件已发送"
                alertMessage = "请检查您的邮箱，按照邮件指示重置密码。"
            }
            showingResetPasswordAlert = true
        }
    }

    private func deleteAccount() {
        isLoading = true
        auth.deleteAccount { error in
            isLoading = false
            if let error = error {
                alertTitle = "错误"
                alertMessage = error.localizedDescription
                showingResetPasswordAlert = true
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
