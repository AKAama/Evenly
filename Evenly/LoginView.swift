//
//  LoginView.swift
//  Evenly
//
//  Login and Register views
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var isShowingRegister = false

    var body: some View {
        NavigationStack {
            if isShowingRegister {
                RegisterView(isShowingRegister: $isShowingRegister)
            } else {
                loginView
            }
        }
    }

    private var loginView: some View {
        ScrollView {
            dismissKeyboardGesture
            VStack(spacing: 32) {
                Spacer().frame(height: 60)

                // App Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "equal.circle.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(spacing: 8) {
                    Text("Evenly")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("轻松分摊，愉快记账")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer().frame(height: 32)

                VStack(spacing: 16) {
                    CustomTextField(
                        icon: "envelope.fill",
                        placeholder: "邮箱",
                        text: $auth.loginIdentifier
                    )

                    CustomSecureField(
                        icon: "lock.fill",
                        placeholder: "密码",
                        text: $auth.loginPassword
                    )

                    if let error = auth.loginError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .multilineTextAlignment(.center)
                    }

                    Button {
                        HapticManager.impact(.medium)
                        auth.signIn(identifier: auth.loginIdentifier, password: auth.loginPassword) { error in
                            if let error = error {
                                auth.loginError = error.localizedDescription
                                HapticManager.notificationOccurred(.error)
                            } else {
                                HapticManager.notificationOccurred(.success)
                            }
                        }
                    } label: {
                        HStack {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("登录")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(auth.loginIdentifier.isEmpty || auth.loginPassword.isEmpty ? Color.gray : Color.blue)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.spring(.medium))
                    .disabled(auth.isLoading || auth.loginIdentifier.isEmpty || auth.loginPassword.isEmpty)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                Button {
                    HapticManager.impact(.light)
                    isShowingRegister = true
                } label: {
                    HStack {
                        Text("还没有账号？")
                            .foregroundStyle(.secondary)
                        Text("立即注册")
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                    }
                    .font(.subheadline)
                }

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarHidden(true)
    }

    // 点击空白处收起键盘
    private var dismissKeyboardGesture: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Register View

struct RegisterView: View {
    @EnvironmentObject var auth: AuthManager
    @Binding var isShowingRegister: Bool
    @State private var avatarImage: UIImage?
    @State private var showingImagePicker = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var usernameChecked = false
    @State private var isCheckingUsername = false
    @State private var codeSent = false

    var body: some View {
        ScrollView {
            dismissKeyboardGesture
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }

                Text("点击上传头像")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    // 用户名
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                            TextField("用户名", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: username) { _, newValue in
                                    usernameChecked = false
                                }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                        if !username.isEmpty && !auth.isValidUsername(username) {
                            Text("用户名必须以英文开头，可包含英文、数字、下划线，至少3位")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else if usernameChecked {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("用户名可用")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    // 邮箱
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.secondary)
                            TextField("邮箱", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                        if !email.isEmpty && !auth.isValidEmail(email) {
                            Text("请输入有效的邮箱地址")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }

                        // 发送验证码按钮
                        if auth.isValidEmail(email) && !codeSent {
                            Button {
                                auth.sendVerificationCode(email: email) { error in
                                    if error == nil {
                                        codeSent = true
                                    } else {
                                        auth.registerError = error?.localizedDescription
                                    }
                                }
                            } label: {
                                HStack {
                                    if auth.isSendingCode {
                                        ProgressView()
                                            .tint(.blue)
                                    } else {
                                        Text("发送验证码")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .disabled(auth.isSendingCode)
                        }

                        // 验证码输入
                        if codeSent {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                TextField("验证码", text: $auth.verificationCode)
                                    .keyboardType(.numberPad)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }

                    // 密码
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            SecureField("密码", text: $password)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                        if password.count > 0 && password.count < 6 {
                            Text("密码至少6位")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    // 确认密码
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            SecureField("确认密码", text: $confirmPassword)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("两次输入的密码不一致")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    if let error = auth.registerError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        register()
                    } label: {
                        HStack {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("注册")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canRegister ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canRegister || auth.isLoading)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                Button {
                    isShowingRegister = false
                } label: {
                    Text("已有账号？返回登录")
                        .font(.subheadline)
                }

                Spacer().frame(height: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("注册")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    isShowingRegister = false
                }
            }
        }
    }

    // 点击空白处收起键盘
    private var dismissKeyboardGesture: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var canRegister: Bool {
        auth.isValidUsername(username) &&
        auth.isValidEmail(email) &&
        codeSent &&
        !auth.verificationCode.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func register() {
        auth.signUp(
            username: username,
            email: email,
            phone: "",
            password: password
        ) { error in
            if error == nil {
                isShowingRegister = false
            }
        }
    }
}

// MARK: - Custom Fields

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isFocused ? .blue : .secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isFocused ? .blue : .secondary)
                .frame(width: 20)
            
            if isPasswordVisible {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
            } else {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            }
            
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
