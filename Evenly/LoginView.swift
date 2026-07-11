//
//  LoginView.swift
//  Evenly
//
//  Login and Register views
//

import SwiftUI
import AuthenticationServices

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

    private var canSubmitLogin: Bool {
        !auth.isLoading
            && !auth.loginIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !auth.loginPassword.isEmpty
    }

    private var loginView: some View {
        ZStack {
            EvenlyStyle.softBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }

            Circle()
                .fill(EvenlyStyle.blue.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 2)
                .offset(x: -220, y: -340)
                .allowsHitTesting(false)

            Circle()
                .fill(EvenlyStyle.indigo.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: 240, y: 390)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                // 1) Brand — calm, not competing with actions
                brandHeader
                    .padding(.bottom, 28)

                // 2) Primary path — account login
                loginFormCard
                    .padding(.horizontal, 24)

                // 3) Secondary path — Apple
                alternativeSignInSection
                    .padding(.top, 22)
                    .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // 4) Tertiary — register / guest (text-level, not full-width CTAs)
                footerActions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var brandHeader: some View {
        VStack(spacing: 14) {
            Image("LoginLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
                }
                .shadow(color: EvenlyStyle.brandBlue.opacity(0.20), radius: 22, y: 10)
                .accessibilityLabel("Evenly 图标")
                .accessibilityIdentifier("login-logo")

            VStack(spacing: 6) {
                Text("Evenly")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(.primary)
                Text("轻松分摊，愉快记账")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loginFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("账号登录")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(spacing: 12) {
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
            }

            HStack {
                Spacer(minLength: 0)
                Button("忘记密码？") {
                    focusedField = nil
                    HapticManager.press()
                    isShowingPasswordReset = true
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(EvenlyStyle.brandBlue)
                .buttonStyle(.plain)
            }
            .padding(.top, -6)

            if let error = auth.loginError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 1)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            // Single primary CTA — filled, continuous corner, press feedback via springPrimary
            Button(action: submitLogin) {
                HStack(spacing: 8) {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("登录")
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canSubmitLogin ? EvenlyStyle.brandBlue : Color.secondary.opacity(0.28))
                        .shadow(
                            color: canSubmitLogin ? EvenlyStyle.brandBlue.opacity(0.28) : .clear,
                            radius: 14,
                            y: 6
                        )
                }
                .foregroundStyle(.white)
                .animation(EvenlyMotion.press, value: canSubmitLogin)
            }
            .buttonStyle(.springPrimary)
            .disabled(!canSubmitLogin)
            .padding(.top, 4)
            .accessibilityIdentifier("login-submit")
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(0.92))
                )
                .shadow(color: Color.black.opacity(0.07), radius: 28, y: 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }

    private var alternativeSignInSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.secondary.opacity(0.14))
                    .frame(height: 1)
                Text("其他方式")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                Capsule()
                    .fill(Color.secondary.opacity(0.14))
                    .frame(height: 1)
            }

            // Secondary path — present, but not competing with the primary filled CTA
            SignInWithAppleButton(
                .signIn,
                onRequest: auth.prepareAppleSignIn,
                onCompletion: auth.handleAppleSignIn
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .disabled(auth.isLoading)
            .opacity(auth.isLoading ? 0.55 : 1)
            .accessibilityIdentifier("sign-in-with-apple")
        }
    }

    private var footerActions: some View {
        VStack(spacing: 16) {
            Button {
                focusedField = nil
                HapticManager.press()
                isShowingRegister = true
            } label: {
                (
                    Text("还没有账号？")
                        .foregroundStyle(.secondary)
                    + Text("立即注册")
                        .fontWeight(.semibold)
                        .foregroundStyle(EvenlyStyle.brandBlue)
                )
                .font(.subheadline)
            }
            .buttonStyle(.plain)

            Button {
                focusedField = nil
                HapticManager.press()
                auth.enterGuestMode()
            } label: {
                Text("先本地试用，稍后再登录")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("continue-as-guest")

            Text("本地数据仅保存在本机。登录后可云同步与多人协作。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)
        }
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
                        if !confirmPassword.isEmpty && newPassword != confirmPassword {
                            Text("两次输入的密码不一致")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if !newPassword.isEmpty && newPassword.count < 6 {
                            Text("密码至少 6 位")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                if let message { Section { Text(message).foregroundStyle(.secondary) } }
            }
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { submit() } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(codeSent ? "重置" : "发送验证码")
                        }
                    }
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

// MARK: - Register View (stepped wizard — not a long survey form)

struct RegisterView: View {
    @EnvironmentObject var auth: AuthManager
    @Binding var isShowingRegister: Bool

    private enum Step: Int, CaseIterable {
        case email = 0
        case password = 1
        case profile = 2

        var title: String {
            switch self {
            case .email: return "用邮箱开始"
            case .password: return "设置密码"
            case .profile: return "怎么称呼你"
            }
        }

        var subtitle: String {
            switch self {
            case .email: return "我们会发一封验证码，确认是你本人"
            case .password: return "至少 6 位，登录时用得到"
            case .profile: return "朋友在账本里会看到这个名字"
            }
        }
    }

    private enum RegisterField: Hashable {
        case email, code, password, confirmPassword, displayName, username
    }

    @State private var step: Step = .email
    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var codeSent = false
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: RegisterField?

    var body: some View {
        ZStack {
            EvenlyStyle.softBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }

            Circle()
                .fill(EvenlyStyle.blue.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 2)
                .offset(x: -200, y: -320)
                .allowsHitTesting(false)

            Circle()
                .fill(EvenlyStyle.indigo.opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: 220, y: 360)
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepIndicator
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(-0.4)
                            .foregroundStyle(.primary)
                        Text(step.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .id(step)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                    stepCard
                        .id("card-\(step.rawValue)")
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                    if let error = auth.registerError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.top, 1)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }

                    primaryButton

                    if step == .email {
                        Button {
                            HapticManager.press()
                            isShowingRegister = false
                        } label: {
                            (
                                Text("已有账号？")
                                    .foregroundStyle(.secondary)
                                + Text("返回登录")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(EvenlyStyle.brandBlue)
                            )
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(step == .email ? "取消" : "上一步") {
                    HapticManager.press()
                    withAnimation(EvenlyMotion.ui) { goBack() }
                }
            }
            ToolbarItem(placement: .principal) {
                Text("注册")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
            }
        }
        .animation(EvenlyMotion.ui, value: step)
        .animation(EvenlyMotion.press, value: codeSent)
        .animation(EvenlyMotion.press, value: auth.registerError)
        .onAppear { HapticManager.prepare() }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? EvenlyStyle.brandBlue : Color.secondary.opacity(0.18))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("注册进度，第 \(step.rawValue + 1) 步，共 \(Step.allCases.count) 步")
    }

    @ViewBuilder
    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step {
            case .email:
                emailStepContent
            case .password:
                passwordStepContent
            case .profile:
                profileStepContent
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground).opacity(0.92))
                )
                .shadow(color: Color.black.opacity(0.07), radius: 28, y: 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }

    private var emailStepContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            registerField(
                icon: "envelope.fill",
                isFocused: focusedField == .email
            ) {
                TextField("邮箱", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(codeSent ? .next : .send)
                    .onSubmit {
                        if codeSent {
                            focusedField = .code
                        } else if canSendCode {
                            sendCode()
                        }
                    }
            }

            if !email.isEmpty && !auth.isValidEmail(email) {
                fieldHint("请输入有效的邮箱地址", isError: true)
            }

            if codeSent {
                registerField(icon: "number", isFocused: focusedField == .code) {
                    TextField("6 位验证码", text: $auth.verificationCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .code)
                }

                HStack {
                    Text("验证码已发送到邮箱")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        sendCode()
                    } label: {
                        if auth.isSendingCode {
                            ProgressView()
                        } else {
                            Text("重新发送")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(EvenlyStyle.brandBlue)
                        }
                    }
                    .disabled(auth.isSendingCode)
                }
            }
        }
    }

    private var passwordStepContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            registerField(icon: "lock.fill", isFocused: focusedField == .password) {
                Group {
                    if isPasswordVisible {
                        TextField("密码（至少 6 位）", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("密码（至少 6 位）", text: $password)
                    }
                }
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirmPassword }

                Button {
                    HapticManager.selectionChanged()
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !password.isEmpty && password.count < 6 {
                fieldHint("密码至少 6 位", isError: true)
            }

            registerField(icon: "lock.rotation", isFocused: focusedField == .confirmPassword) {
                SecureField("再输入一次", text: $confirmPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.continue)
                    .onSubmit {
                        if canContinuePassword {
                            withAnimation(EvenlyMotion.ui) { advanceFromPassword() }
                        }
                    }
            }

            if !confirmPassword.isEmpty && password != confirmPassword {
                fieldHint("两次输入不一致", isError: true)
            }
        }
    }

    private var profileStepContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("头像可以之后在设置里再加，先把名字定好就行。")
                .font(.caption)
                .foregroundStyle(.secondary)

            registerField(icon: "person.text.rectangle", isFocused: focusedField == .displayName) {
                TextField("显示名称（朋友会看到）", text: $displayName)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .username }
            }

            registerField(icon: "at", isFocused: focusedField == .username) {
                TextField("用户名（登录用）", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.join)
                    .onSubmit {
                        if canRegister { register() }
                    }
            }

            if !username.isEmpty && !auth.isValidUsername(username) {
                fieldHint("英文开头，可含数字和下划线，至少 3 位", isError: true)
            } else if auth.isValidUsername(username) {
                fieldHint("登录时也可用 @\(username)", isError: false)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            HapticManager.impact(.medium)
            handlePrimary()
        } label: {
            HStack {
                if auth.isLoading || auth.isSendingCode {
                    ProgressView().tint(.white)
                } else {
                    Text(primaryTitle)
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(primaryEnabled ? EvenlyStyle.brandBlue : Color.secondary.opacity(0.28))
                    .shadow(
                        color: primaryEnabled ? EvenlyStyle.brandBlue.opacity(0.28) : .clear,
                        radius: 14,
                        y: 6
                    )
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.springPrimary)
        .disabled(!primaryEnabled || auth.isLoading || auth.isSendingCode)
        .animation(EvenlyMotion.press, value: primaryEnabled)
    }

    private var primaryTitle: String {
        switch step {
        case .email:
            return codeSent ? "下一步" : "发送验证码"
        case .password:
            return "下一步"
        case .profile:
            return "完成注册"
        }
    }

    private var primaryEnabled: Bool {
        switch step {
        case .email:
            return codeSent ? canContinueEmail : canSendCode
        case .password:
            return canContinuePassword
        case .profile:
            return canRegister
        }
    }

    private var canSendCode: Bool {
        auth.isValidEmail(email)
    }

    private var canContinueEmail: Bool {
        canSendCode && codeSent && !auth.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canContinuePassword: Bool {
        password.count >= 6 && password == confirmPassword
    }

    private var canRegister: Bool {
        canContinueEmail
            && canContinuePassword
            && auth.isValidUsername(username)
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func registerField<Content: View>(
        icon: String,
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isFocused ? EvenlyStyle.brandBlue : .secondary)
                .frame(width: 20)
                .animation(EvenlyMotion.press, value: isFocused)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isFocused ? EvenlyStyle.brandBlue.opacity(0.85) : Color.primary.opacity(0.06),
                    lineWidth: isFocused ? 1.5 : 1
                )
        }
        .shadow(
            color: isFocused ? EvenlyStyle.brandBlue.opacity(0.12) : .clear,
            radius: 10,
            y: 3
        )
        .animation(EvenlyMotion.press, value: isFocused)
    }

    private func fieldHint(_ text: String, isError: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(isError ? .red : .secondary)
    }

    private func handlePrimary() {
        auth.registerError = nil
        switch step {
        case .email:
            if codeSent {
                focusedField = nil
                withAnimation(EvenlyMotion.ui) { step = .password }
            } else {
                sendCode()
            }
        case .password:
            withAnimation(EvenlyMotion.ui) { advanceFromPassword() }
        case .profile:
            register()
        }
    }

    private func advanceFromPassword() {
        focusedField = nil
        step = .profile
        if displayName.isEmpty {
            // Sensible default so the last step feels short.
            displayName = email.split(separator: "@").first.map(String.init) ?? ""
        }
        if username.isEmpty {
            let base = displayName
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            if auth.isValidUsername(base) {
                username = base
            } else if let first = base.first, first.isNumber {
                username = "u_\(base)"
            }
        }
    }

    private func goBack() {
        auth.registerError = nil
        focusedField = nil
        switch step {
        case .email:
            isShowingRegister = false
        case .password:
            step = .email
        case .profile:
            step = .password
        }
    }

    private func sendCode() {
        auth.sendVerificationCode(email: email) { error in
            Task { @MainActor in
                if error == nil {
                    withAnimation(EvenlyMotion.press) {
                        codeSent = true
                    }
                    focusedField = .code
                    HapticManager.notificationOccurred(.success)
                } else {
                    auth.registerError = error?.localizedDescription
                    HapticManager.notificationOccurred(.error)
                }
            }
        }
    }

    private func register() {
        focusedField = nil
        auth.signUp(
            username: username,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email,
            phone: "",
            password: password
        ) { error in
            Task { @MainActor in
                if error == nil {
                    HapticManager.notificationOccurred(.success)
                    // Auth state change leaves LoginView; no need to flip the register flag.
                } else {
                    HapticManager.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Custom Fields

private struct LoginFieldChrome: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused
                            ? EvenlyStyle.brandBlue.opacity(0.85)
                            : Color.primary.opacity(0.06),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .shadow(
                color: isFocused ? EvenlyStyle.brandBlue.opacity(0.12) : .clear,
                radius: 10,
                y: 3
            )
            .animation(EvenlyMotion.press, value: isFocused)
    }
}

private struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let focusedField: FocusState<LoginField?>.Binding
    let field: LoginField

    private var isFocused: Bool { focusedField.wrappedValue == field }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isFocused ? EvenlyStyle.brandBlue : .secondary)
                .frame(width: 20)
                .animation(EvenlyMotion.press, value: isFocused)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focusedField, equals: field)
        }
        .modifier(LoginFieldChrome(isFocused: isFocused))
    }
}

private struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let focusedField: FocusState<LoginField?>.Binding
    let field: LoginField
    @State private var isPasswordVisible = false

    private var isFocused: Bool { focusedField.wrappedValue == field }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isFocused ? EvenlyStyle.brandBlue : .secondary)
                .frame(width: 20)
                .animation(EvenlyMotion.press, value: isFocused)

            Group {
                if isPasswordVisible {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .focused(focusedField, equals: field)

            Button {
                HapticManager.selectionChanged()
                withAnimation(EvenlyMotion.press) {
                    isPasswordVisible.toggle()
                }
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPasswordVisible ? "隐藏密码" : "显示密码")
        }
        .modifier(LoginFieldChrome(isFocused: isFocused))
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
