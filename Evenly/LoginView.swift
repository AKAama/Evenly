//
//  LoginView.swift
//  Evenly
//
//  Login and Register views
//

import SwiftUI

private enum LoginField: Hashable {
    case identifier
    case password
}

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var isShowingRegister = false
    @State private var isShowingPasswordReset = false
    @FocusState private var focusedField: LoginField?

    var body: some View {
        NavigationStack {
            if isShowingRegister {
                RegisterView(isShowingRegister: $isShowingRegister)
            } else {
                loginView
            }
        }
        .sheet(isPresented: $isShowingPasswordReset) {
            ForgotPasswordView().environmentObject(auth)
        }
    }

    private var loginView: some View {
        ZStack {
            EvenlyStyle.softBackground
                .ignoresSafeArea()

            Circle()
                .fill(EvenlyStyle.blue.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 2)
                .offset(x: -220, y: -340)

            Circle()
                .fill(EvenlyStyle.indigo.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: 240, y: 390)

            VStack(spacing: 20) {
                    Spacer(minLength: 12)

                    Image("LoginLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityLabel("Evenly 图标")
                        .accessibilityIdentifier("login-logo")
                        .shadow(color: EvenlyStyle.blue.opacity(0.25), radius: 24, y: 10)

                    VStack(spacing: 8) {
                        Text("Evenly")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text("轻松分摊，愉快记账")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    VStack(spacing: 16) {
                        CustomTextField(
                            icon: "envelope.fill",
                            placeholder: "邮箱或用户名",
                            text: $auth.loginIdentifier,
                            focusedField: $focusedField,
                            field: .identifier
                        )
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier("login-email")
                        .id(LoginField.identifier)

                        CustomSecureField(
                            icon: "lock.fill",
                            placeholder: "密码",
                            text: $auth.loginPassword,
                            focusedField: $focusedField,
                            field: .password
                        )
                        .submitLabel(.go)
                        .onSubmit { submitLogin() }
                        .accessibilityIdentifier("login-password")
                        .id(LoginField.password)

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

                        Button(action: submitLogin) {
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
                            .fill(auth.loginIdentifier.isEmpty || auth.loginPassword.isEmpty ? Color.gray : EvenlyStyle.blue)
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.spring(.medium))
                        .disabled(auth.isLoading || auth.loginIdentifier.isEmpty || auth.loginPassword.isEmpty)
                    }
                    .padding(.horizontal, 24)

                    Button("忘记密码？") {
                        focusedField = nil
                        isShowingPasswordReset = true
                    }
                    .font(.subheadline)

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

                    Button {
                        HapticManager.impact(.light)
                        auth.enterGuestMode()
                    } label: {
                        Label("无需登录，本地使用", systemImage: "iphone")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("continue-as-guest")

                    Text("本地模式无需注册，数据仅保存在这台设备上。登录后可使用云同步与多人协作。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer(minLength: 12)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
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

    private func submitLogin() {
        focusedField = nil
        HapticManager.impact(.medium)
        auth.signIn(identifier: auth.loginIdentifier, password: auth.loginPassword) { error in
            if let error {
                auth.loginError = error.localizedDescription
                HapticManager.notificationOccurred(.error)
            } else {
                HapticManager.notificationOccurred(.success)
            }
        }
    }
}

struct ForgotPasswordView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var codeSent = false
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("注册邮箱") {
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                if codeSent {
                    Section("验证码") {
                        TextField("6 位验证码", text: $code).keyboardType(.numberPad)
                    }
                    Section("新密码") {
                        SecureField("新密码（至少 6 位）", text: $newPassword)
                        SecureField("再次输入新密码", text: $confirmPassword)
                    }
                }
                if let message { Section { Text(message).foregroundStyle(.secondary) } }
            }
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(codeSent ? "重置" : "发送验证码") { submit() }
                        .disabled(!canSubmit || isLoading)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard auth.isValidEmail(email) else { return false }
        if !codeSent { return true }
        return !code.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func submit() {
        isLoading = true
        message = nil
        if codeSent {
            auth.resetPassword(email: email, code: code, newPassword: newPassword) { error in
                isLoading = false
                if let error { message = error.localizedDescription }
                else { dismiss() }
            }
        } else {
            auth.sendPasswordResetCode(email: email) { error in
                isLoading = false
                if let error { message = error.localizedDescription }
                else {
                    codeSent = true
                    message = "如果该邮箱已注册，验证码将发送至邮箱"
                }
            }
        }
    }
}

// MARK: - Register View

struct RegisterView: View {
    @EnvironmentObject var auth: AuthManager
    @Binding var isShowingRegister: Bool
    @State private var avatarImage: UIImage?
    @State private var showingImagePicker = false
    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var usernameChecked = false
    @State private var isCheckingUsername = false
    @State private var codeSent = false
    @FocusState private var focusedField: RegisterField?

    enum RegisterField: Hashable {
        case displayName, username, email, code, password, confirmPassword
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(.secondary)
                        TextField("显示名称", text: $displayName)
                            .focused($focusedField, equals: .displayName)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .id(RegisterField.displayName)

                    // 用户名
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                            TextField("用户名", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .username)
                                .onChange(of: username) { _, newValue in
                                    usernameChecked = false
                                }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .id(RegisterField.username)

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
                                .focused($focusedField, equals: .email)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .id(RegisterField.email)

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
                                    .focused($focusedField, equals: .code)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .id(RegisterField.code)
                        }
                    }

                    // 密码
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            SecureField("密码", text: $password)
                                .focused($focusedField, equals: .password)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .id(RegisterField.password)

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
                                .focused($focusedField, equals: .confirmPassword)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .id(RegisterField.confirmPassword)

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
        .onChange(of: focusedField) { _, field in
            guard let field else { return }
            withAnimation { proxy.scrollTo(field, anchor: .bottom) }
        }
        }
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
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        auth.isValidEmail(email) &&
        codeSent &&
        !auth.verificationCode.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func register() {
        auth.signUp(
            username: username,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
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

private struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let focusedField: FocusState<LoginField?>.Binding
    let field: LoginField

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(focusedField.wrappedValue == field ? .blue : .secondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField.wrappedValue == field ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}

private struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let focusedField: FocusState<LoginField?>.Binding
    let field: LoginField
    @State private var isPasswordVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(focusedField.wrappedValue == field ? .blue : .secondary)
                .frame(width: 20)

            if isPasswordVisible {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: field)
            } else {
                SecureField(placeholder, text: $text)
                    .focused(focusedField, equals: field)
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
                        .stroke(focusedField.wrappedValue == field ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
