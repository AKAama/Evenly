//
//  SettingsView.swift
//
//  Settings view with modern design
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingResetPasswordAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingChangePassword = false

    var body: some View {
        NavigationStack {
            List {
                if let user = auth.user {
                    Section {
                        HStack(spacing: 16) {
                            if let avatarImage = auth.userProfile?.avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(auth.userProfile?.displayName ?? user.displayName ?? "用户")
                                    .font(.headline)
                                    .dynamicTypeSize(.accessibility2)
                                if let username = auth.userProfile?.username {
                                    Text("@\(username)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
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
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("隐私政策", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("服务条款", systemImage: "doc.text")
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
        }
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
