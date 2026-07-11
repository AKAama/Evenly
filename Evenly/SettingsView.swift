//
//  SettingsView.swift
//
//  Settings view with modern design
//

import SwiftUI
import PhotosUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var notifications = NotificationManager.shared

    private var versionLabel: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
        return "\(version) (\(buildConfiguration))"
    }

    private var buildConfiguration: String {
        #if DEBUG
        "Debug"
        #else
        "Release"
        #endif
    }

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

                Section("通知") {
                    HStack {
                        Label("系统通知", systemImage: "bell.badge")
                        Spacer()
                        Text(notificationStatusLabel)
                            .foregroundStyle(.secondary)
                    }
                    if notifications.authorizationStatus == .denied {
                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            Label("前往系统设置", systemImage: "gear")
                        }
                    }
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
                        Text(versionLabel)
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

    private var notificationStatusLabel: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "已开启"
        case .denied: "已关闭"
        case .notDetermined: "未设置"
        @unknown default: "未知"
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
    @State private var pendingAvatarImage: UIImage?
    @State private var isUploadingAvatar = false
    @State private var isPreparingAvatar = false
    @State private var showingAvatarOptions = false
    @State private var pendingAvatarAction: AvatarAction?
    @State private var showingAvatarPreview = false
    @State private var showingAvatarPicker = false
    @State private var showingAvatarEditor = false
    @State private var showingDeleteAccountConfirmation = false

    var body: some View {
        List {
            if let user = auth.user {
                Section {
                    HStack {
                        Spacer()
                        Button {
                            HapticManager.impact(.light)
                            showingAvatarOptions = true
                        } label: {
                            ZStack {
                                RemoteAvatarView(
                                    avatarUrl: auth.userProfile?.avatarUrl,
                                    localImage: selectedAvatarImage ?? auth.avatarImage,
                                    fallbackText: auth.userProfile?.displayName ?? user.email,
                                    size: 88
                                )
                                if isUploadingAvatar || isPreparingAvatar {
                                    Circle().fill(.black.opacity(0.35)).frame(width: 88, height: 88)
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploadingAvatar || isPreparingAvatar)
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
        .sheet(isPresented: $showingAvatarOptions, onDismiss: performPendingAvatarAction) {
            AvatarOptionsSheet { action in
                pendingAvatarAction = action
                showingAvatarOptions = false
            }
            .presentationDetents([.height(176)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingAvatarEditor) {
            if let pendingAvatarImage {
                AvatarEditorView(image: pendingAvatarImage) { editedImage in
                    selectedAvatarImage = editedImage
                    uploadAvatar(image: editedImage)
                }
            }
        }
        .fullScreenCover(isPresented: $showingAvatarPreview) {
            AvatarPreviewView(
                avatarUrl: auth.userProfile?.avatarUrl,
                localImage: selectedAvatarImage ?? auth.avatarImage,
                fallbackText: auth.userProfile?.displayName ?? auth.user?.email ?? "?"
            )
        }
        .photosPicker(isPresented: $showingAvatarPicker, selection: $avatarItem, matching: .images)
        .alert(alertTitle, isPresented: $showingAlert) { Button("确定", role: .cancel) {} } message: { Text(alertMessage) }
        .alert("永久删除账户？", isPresented: $showingDeleteAccountConfirmation) {
            Button("取消", role: .cancel) {}
            Button("永久删除", role: .destructive) { deleteAccount() }
        } message: {
            Text("你的个人资料、拥有的账本、共享账本中的关联记录将被永久删除。此操作无法撤销。")
        }
        .onAppear { auth.refreshAuthMethods() }
    }

    private func performPendingAvatarAction() {
        guard let action = pendingAvatarAction else { return }
        pendingAvatarAction = nil

        switch action {
        case .preview:
            showingAvatarPreview = true
        case .replace:
            showingAvatarPicker = true
        }
    }

    private func handleAvatarSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isPreparingAvatar = true
        HapticManager.impact(.medium)
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                avatarItem = nil
                isPreparingAvatar = false
                switch result {
                case .success(let data):
                    guard let data, let image = UIImage(data: data) else {
                        showAlert(title: "上传失败", message: "无法读取所选图片")
                        return
                    }
                    pendingAvatarImage = image
                    showingAvatarEditor = true
                case .failure:
                    showAlert(title: "上传失败", message: "图片加载失败,请重试")
                }
            }
        }
    }

    private func uploadAvatar(image: UIImage) {
        isUploadingAvatar = true
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
                pendingAvatarImage = nil
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

private enum AvatarAction {
    case preview
    case replace
}

private struct AvatarOptionsSheet: View {
    let onSelect: (AvatarAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            optionButton("查看大图") {
                onSelect(.preview)
            }

            Divider()
                .padding(.horizontal, 24)

            optionButton("更换头像") {
                onSelect(.replace)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func optionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(EvenlyStyle.brandBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AvatarPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let avatarUrl: String?
    let localImage: UIImage?
    let fallbackText: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Group {
                if let localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFit()
                } else if let url = normalizedAvatarURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                        } else {
                            fallbackAvatar
                        }
                    }
                } else {
                    fallbackAvatar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
    }

    private var fallbackAvatar: some View {
        Text(String(fallbackText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
            .font(.system(size: 88, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 220, height: 220)
            .background(EvenlyStyle.brandBlue, in: Circle())
    }

    private var normalizedAvatarURL: URL? {
        guard let avatarUrl, !avatarUrl.isEmpty else { return nil }
        guard var components = URLComponents(string: avatarUrl) else { return nil }
        if components.host == "cos.ismyh.cn" {
            components.host = "evenly-1325650734.cos.ap-nanjing.myqcloud.com"
        }
        return components.url
    }
}

private struct AvatarEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let onSave: (UIImage) -> Void

    private let cropSide: CGFloat = 300
    private let outputSide: CGFloat = 512
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 8)

                ZStack {
                    Color.black.opacity(0.92)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSide, height: cropSide)
                        .scaleEffect(scale)
                        .rotationEffect(rotation)
                        .offset(offset)
                        .gesture(dragGesture.simultaneously(with: magnificationGesture).simultaneously(with: rotationGesture))

                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                        .frame(width: cropSide, height: cropSide)
                        .allowsHitTesting(false)

                    Rectangle()
                        .fill(.black.opacity(0.38))
                        .mask {
                            Rectangle()
                                .overlay {
                                    Circle()
                                        .frame(width: cropSide, height: cropSide)
                                        .blendMode(.destinationOut)
                                }
                        }
                        .allowsHitTesting(false)
                }
                .compositingGroup()
                .frame(width: cropSide, height: cropSide)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 22, y: 10)

                VStack(spacing: 18) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundStyle(.secondary)
                        Slider(value: $scale, in: 1...4)
                            .tint(EvenlyStyle.brandBlue)
                            .onChange(of: scale) { _, newValue in
                                lastScale = newValue
                            }
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 14) {
                        Button {
                            rotation -= .degrees(90)
                            lastRotation = rotation
                            HapticManager.selection.selectionChanged()
                        } label: {
                            Label("左转", systemImage: "rotate.left")
                        }

                        Button {
                            resetTransform()
                        } label: {
                            Label("重置", systemImage: "arrow.counterclockwise")
                        }

                        Button {
                            rotation += .degrees(90)
                            lastRotation = rotation
                            HapticManager.selection.selectionChanged()
                        } label: {
                            Label("右转", systemImage: "rotate.right")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)

                Text("拖动调整位置，双指缩放或旋转。头像会按圆形区域居中裁剪。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("编辑头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("使用") {
                        onSave(renderedAvatar())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                rotation = lastRotation + value
            }
            .onEnded { _ in
                lastRotation = rotation
            }
    }

    private func resetTransform() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
            rotation = .zero
            lastRotation = .zero
        }
        HapticManager.selection.selectionChanged()
    }

    private func renderedAvatar() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide))
        let cropScale = outputSide / cropSide
        let imageScale = max(cropSide / image.size.width, cropSide / image.size.height) * scale * cropScale
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: outputSide, height: outputSide))

            let cgContext = context.cgContext
            cgContext.translateBy(
                x: outputSide / 2 + offset.width * cropScale,
                y: outputSide / 2 + offset.height * cropScale
            )
            cgContext.rotate(by: CGFloat(rotation.radians))
            cgContext.scaleBy(x: imageScale, y: imageScale)
            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
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
