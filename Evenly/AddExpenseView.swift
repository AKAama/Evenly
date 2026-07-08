//
//  AddExpenseView.swift
//  Evenly
//
//  Created by alex_yehui on 2025/12/14.
//  Modern expense input with animations and haptics
//

import SwiftUI
import AVFoundation
import Combine

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var selectedPayerId: UUID?
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var isSaving = false
    @State private var isCreatingVoiceDraft = false
    @State private var transcript: String?
    @State private var errorMessage: String?
    @State private var selectedPresetId: String?
    @State private var selectedPresetGroupId: String = "餐饮"
    @State private var isPeoplePickerPresented = false
    @StateObject private var voiceRecorder = VoiceExpenseRecorder()
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case title
        case amount
    }

    private var primaryBlue: Color {
        EvenlyStyle.brandBlueAccent
    }
    private var mainSoftBlue: Color {
        EvenlyStyle.brandBlueSoft(colorScheme)
    }
    private var mainTopGlow: Color {
        EvenlyStyle.brandBlueGlow(colorScheme)
    }
    private var mainGlassStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.white.opacity(0.72)
    }
    private var mainShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.28)
            : EvenlyStyle.brandBlueAccent.opacity(0.10)
    }
    private var controlFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color(.tertiarySystemGroupedBackground)
    }

    let participants: [Person]
    let currentUserId: String?
    let ledgerId: UUID?
    var onSave: @MainActor (Expense) async -> Result<Void, Error>
    private let existingId: UUID?
    /// 已加入的注册成员（可作为付款人）
    private var registeredParticipants: [Person] {
        participants.filter { $0.isActive && !$0.isTemporary && ($0.userId?.isEmpty == false) }
    }
    /// 可作为参与人分摊的成员：所有已加入的人（包括临时成员）
    private var selectableParticipants: [Person] {
        participants.filter { $0.isActive }
    }
    private var selectedPayer: Person? {
        guard let selectedPayerId else { return nil }
        return registeredParticipants.first { $0.id == selectedPayerId }
    }
    private var selectedParticipants: [Person] {
        participants.filter { $0.isActive && selectedParticipantIds.contains($0.id) }
    }
    private var selectedPreset: ExpensePreset? {
        Self.expensePresets.flatMap(\.items).first { $0.id == selectedPresetId }
    }
    private var selectedPresetGroup: ExpensePresetGroup {
        Self.expensePresets.first { $0.id == selectedPresetGroupId } ?? Self.expensePresets[0]
    }
    private var participantSummary: String {
        guard !selectedParticipants.isEmpty else { return "还没选择参与人" }
        let names = selectedParticipants.prefix(3).map(\.name).joined(separator: "、")
        if selectedParticipants.count > 3 {
            return "\(names) 等 \(selectedParticipants.count) 人"
        }
        return names
    }
    private var splitAmountText: String? {
        guard let amount = Decimal(string: amountText), amount > 0, !selectedParticipants.isEmpty else { return nil }
        let value = NSDecimalNumber(decimal: amount)
            .dividing(by: NSDecimalNumber(value: selectedParticipants.count))
        return formatAmountForDisplay(value.decimalValue)
    }

    init(expense: Expense? = nil, participants: [Person], currentUserId: String? = nil, ledgerId: UUID? = nil, onSave: @escaping @MainActor (Expense) async -> Result<Void, Error>) {
        self.participants = participants
        self.currentUserId = currentUserId
        self.ledgerId = ledgerId
        self.onSave = onSave
        self.existingId = expense?.id
        _title = State(initialValue: expense?.title ?? "")
        if let amount = expense?.amount {
            _amountText = State(initialValue: formatAmountForInput(amount))
        }
        // Only active registered members qualify as default payer
        let activeRegistered = participants.filter { $0.isActive && !$0.isTemporary && $0.userId?.isEmpty == false }
        let defaultPayer = activeRegistered.first { $0.userId == currentUserId } ?? activeRegistered.first
        _selectedPayerId = State(initialValue: expense?.payer.id ?? defaultPayer?.id)
        // Default participants: only active members (skip pending invitations)
        let initialParticipants = expense?.participants ?? (defaultPayer.map { [$0] } ?? [])
        _selectedParticipantIds = State(initialValue: Set(
            initialParticipants.filter { $0.isActive }.map(\.id)
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard

                    presetCard
                    peopleSummaryCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background {
                ZStack(alignment: .top) {
                    Color(.systemGroupedBackground)
                    LinearGradient(
                        colors: [mainTopGlow, Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                        .frame(height: 300)
                }
                .ignoresSafeArea()
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: selectedParticipantIds.count)
            .navigationTitle(existingId == nil ? "新建账单" : "编辑账单")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPeoplePickerPresented) {
                ExpensePeoplePickerView(
                    participants: participants,
                    selectedPayerId: $selectedPayerId,
                    selectedParticipantIds: $selectedParticipantIds
                )
                .presentationDetents([.large])
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        HapticManager.impact(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveExpense()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存").fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                HapticManager.prepare()
                if selectedPayerId == nil, let first = registeredParticipants.first {
                    selectedPayerId = first.id
                }
                if let selectedPayer {
                    selectedParticipantIds.insert(selectedPayer.id)
                } else if selectedParticipantIds.isEmpty, let first = registeredParticipants.first {
                    selectedParticipantIds.insert(first.id)
                }
                cleanUnavailableSelections()
            }
            .onDisappear {
                voiceRecorder.cancel()
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("这笔花了", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if existingId == nil, ledgerId != nil {
                    voiceIconButton
                }
                if let selectedPreset {
                    Label(selectedPreset.name, systemImage: selectedPreset.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(primaryBlue.opacity(colorScheme == .dark ? 0.18 : 0.1), in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("¥")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .onChange(of: amountText) { _, newValue in
                        amountText = formatAmountInput(newValue)
                        HapticManager.selection.selectionChanged()
                    }
            }
            .padding(.vertical, 4)

            HStack(spacing: 10) {
                TextField("写点什么，例如周五晚餐", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .font(.title3.weight(.semibold))
                    .onSubmit { focusedField = .amount }
                    .onChange(of: title) { _, newValue in
                        if let selectedPreset, selectedPreset.name != newValue {
                            selectedPresetId = nil
                        }
                    }
                Button {
                    focusedField = .title
                } label: {
                    Image(systemName: "text.cursor")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(controlFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑账单标题")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let transcript {
                Text(transcript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text(splitAmountText.map { "约 ¥\($0) / 人" } ?? "先填金额，再选择谁一起分")
                Spacer()
                Button {
                    focusedField = .amount
                } label: {
                    Image(systemName: "pencil")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .background(controlFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑金额")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemGroupedBackground), mainSoftBlue.opacity(colorScheme == .dark ? 0.40 : 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(mainGlassStroke, lineWidth: 0.8)
        }
        .shadow(color: mainShadow, radius: 24, y: 12)
    }

    private var voiceIconButton: some View {
        Button {
            toggleVoiceRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(voiceRecorder.isRecording ? Color.red.opacity(colorScheme == .dark ? 0.22 : 0.14) : primaryBlue.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 36, height: 36)
                if isCreatingVoiceDraft {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: voiceRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(voiceRecorder.isRecording ? .red : primaryBlue)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isCreatingVoiceDraft)
        .accessibilityLabel(voiceRecorder.isRecording ? "停止并生成草稿" : "语音记账")
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("类别", systemImage: "square.grid.2x2.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.expensePresets) { group in
                        presetGroupButton(group)
                    }
                }
                .padding(.horizontal, 1)
            }

            Divider()
                .padding(.vertical, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedPresetGroup.items) { preset in
                        presetButton(preset)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .expenseInputCard()
    }

    private var peopleSummaryCard: some View {
        VStack(spacing: 12) {
            Button {
                focusedField = nil
                isPeoplePickerPresented = true
                HapticManager.impact(.light)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(primaryBlue)
                        .frame(width: 30, height: 30)
                        .background(primaryBlue.opacity(colorScheme == .dark ? 0.18 : 0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("付款与参与人")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("付款人：\(selectedPayer?.name ?? "未选择")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(selectedParticipants.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(primaryBlue.opacity(colorScheme == .dark ? 0.18 : 0.1), in: Capsule())
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Text(participantSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .expenseInputCard()
        .onAppear {
            if selectedPayerId == nil, let first = registeredParticipants.first(where: { $0.userId == currentUserId }) ?? registeredParticipants.first {
                selectedPayerId = first.id
            }
            if selectedParticipantIds.isEmpty, let first = registeredParticipants.first {
                selectedParticipantIds.insert(first.id)
            }
            cleanUnavailableSelections()
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.red.opacity(colorScheme == .dark ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func presetGroupButton(_ group: ExpensePresetGroup) -> some View {
        let isSelected = selectedPresetGroup.id == group.id
        return Button {
            focusedField = nil
            selectedPresetGroupId = group.id
            if !group.items.contains(where: { $0.id == selectedPresetId }) {
                selectedPresetId = nil
            }
            HapticManager.selection.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: group.icon)
                    .font(.caption.weight(.bold))
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                isSelected ? AnyShapeStyle(primaryBlue) : AnyShapeStyle(controlFill),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? primaryBlue : Color(.separator).opacity(colorScheme == .dark ? 0.55 : 0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func presetButton(_ preset: ExpensePreset) -> some View {
        let isSelected = selectedPresetId == preset.id
        return Button {
            focusedField = nil
            selectedPresetId = preset.id
            title = preset.name
            HapticManager.selection.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.caption.weight(.bold))
                Text(preset.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : primaryBlue)
            .background(
                isSelected ? AnyShapeStyle(primaryBlue) : AnyShapeStyle(primaryBlue.opacity(colorScheme == .dark ? 0.16 : 0.08)),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(primaryBlue.opacity(isSelected ? 0 : (colorScheme == .dark ? 0.34 : 0.22)), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func participantRow(_ participant: Person) -> some View {
        let selectable = participant.isActive
        let isSelected = selectedParticipantIds.contains(participant.id)
        let isLocked = selectedPayerId == participant.id
        return Button {
            guard selectable else { return }
            focusedField = nil
            toggleParticipant(participant)
        } label: {
            HStack(spacing: 12) {
                Text(initials(for: participant))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : primaryBlue)
                    .frame(width: 34, height: 34)
                    .background(
                        isSelected ? AnyShapeStyle(primaryBlue) : AnyShapeStyle(primaryBlue.opacity(colorScheme == .dark ? 0.16 : 0.12)),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(participant.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectable ? .primary : .secondary)
                    Text(participantStatusText(participant, isSelected: isSelected, isLocked: isLocked))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? primaryBlue : Color(.tertiaryLabel))
            }
            .padding(12)
            .background(controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(selectable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
    }

    private func participantStatusText(_ participant: Person, isSelected: Bool, isLocked: Bool) -> String {
        if participant.isPending { return "邀请中" }
        if participant.isTemporary { return "临时成员" }
        if isLocked { return "付款人，必须参与" }
        return isSelected ? "已参与分摊" : "点按加入分摊"
    }

    private func initials(for participant: Person) -> String {
        String(participant.name.prefix(1))
    }

    private static let expensePresets: [ExpensePresetGroup] = [
        ExpensePresetGroup(
            name: "餐饮",
            icon: "fork.knife",
            items: [
                ExpensePreset(name: "早餐", icon: "sunrise.fill"),
                ExpensePreset(name: "午餐", icon: "sun.max.fill"),
                ExpensePreset(name: "晚餐", icon: "moon.stars.fill")
            ]
        ),
        ExpensePresetGroup(
            name: "交通",
            icon: "tram.fill",
            items: [
                ExpensePreset(name: "打车", icon: "car.fill"),
                ExpensePreset(name: "高铁", icon: "train.side.front.car"),
                ExpensePreset(name: "地铁", icon: "tram.fill")
            ]
        ),
        ExpensePresetGroup(
            name: "住宿",
            icon: "bed.double.fill",
            items: [
                ExpensePreset(name: "住宿", icon: "bed.double.fill"),
                ExpensePreset(name: "酒店", icon: "building.2.fill"),
                ExpensePreset(name: "民宿", icon: "house.fill"),
                ExpensePreset(name: "门票", icon: "ticket.fill")
            ]
        )
    ]

    private func cleanUnavailableSelections() {
        let pendingIds = Set(participants.filter { !$0.isActive }.map(\.id))
        selectedParticipantIds.subtract(pendingIds)
        if selectedPayerId.map({ pendingIds.contains($0) }) == true {
            selectedPayerId = registeredParticipants.first(where: { $0.userId == currentUserId })?.id
                ?? registeredParticipants.first?.id
        }
    }

    private func toggleVoiceRecording() {
        focusedField = nil
        errorMessage = nil
        if voiceRecorder.isRecording {
            guard let fileURL = voiceRecorder.stop() else { return }
            createVoiceDraft(from: fileURL)
        } else {
            Task {
                do {
                    try await voiceRecorder.start()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func createVoiceDraft(from fileURL: URL) {
        guard let ledgerId else { return }
        isCreatingVoiceDraft = true
        Task {
            do {
                let data = try Data(contentsOf: fileURL)
                let draft: VoiceExpenseDraft = try await APIClient.shared.requestWithFormData(
                    endpoint: APIEndpoints.voiceExpenseDraft(ledgerId: ledgerId.uuidString),
                    formFields: [:],
                    files: [FileUpload(
                        fieldName: "audio",
                        filename: "voice.m4a",
                        mimeType: "audio/mp4",
                        data: data
                    )]
                )
                await MainActor.run {
                    applyVoiceDraft(draft)
                    isCreatingVoiceDraft = false
                }
            } catch {
                await MainActor.run {
                    isCreatingVoiceDraft = false
                    errorMessage = error.localizedDescription
                    HapticManager.notificationOccurred(.error)
                }
            }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func applyVoiceDraft(_ draft: VoiceExpenseDraft) {
        title = draft.title
        amountText = formatAmountForInput(draft.amount)
        transcript = draft.transcript
        if let payer = registeredParticipants.first(where: { $0.userId == draft.payerUserId }) {
            selectedPayerId = payer.id
        }
        selectedParticipantIds = Set(
            draft.participantMemberIds.compactMap(UUID.init(uuidString:))
        )
        if let selectedPayerId {
            selectedParticipantIds.insert(selectedPayerId)
        }
        voiceRecorder.speak(draft.confirmationText)
        HapticManager.notificationOccurred(.success)
    }

    private var canSave: Bool {
        guard let amount = Decimal(string: amountText),
              !title.isEmpty,
              let payer = selectedPayer,
              payer.userId?.isEmpty == false,
              selectedParticipantIds.contains(payer.id),
              !selectedParticipantIds.isEmpty,
              amount > 0 else {
            return false
        }
        return true
    }

    private func toggleParticipant(_ participant: Person) {
        HapticManager.impact(.light)
        if selectedPayerId == participant.id {
            selectedParticipantIds.insert(participant.id)
            return
        }

        if selectedParticipantIds.contains(participant.id) {
            selectedParticipantIds.remove(participant.id)
        } else {
            selectedParticipantIds.insert(participant.id)
        }
    }

    private func saveExpense() {
        focusedField = nil
        guard let amount = Decimal(string: amountText),
              !title.isEmpty,
              let payer = selectedPayer,
              payer.userId?.isEmpty == false else { return }

        selectedParticipantIds.insert(payer.id)
        // Final safety filter: never send pending-invitation members as participants/payers
        let selectedParticipants = participants.filter {
            $0.isActive && selectedParticipantIds.contains($0.id)
        }
        guard !selectedParticipants.isEmpty else { return }

        errorMessage = nil
        isSaving = true

        let expense = Expense(
            id: existingId ?? UUID(),
            title: title,
            amount: amount,
            payer: payer,
            participants: Array(selectedParticipants)
        )

        Task {
            let result = await onSave(expense)
            await MainActor.run {
                isSaving = false
                switch result {
                case .success:
                    HapticManager.notificationOccurred(.success)
                    dismiss()
                case .failure(let error):
                    HapticManager.notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formatAmountInput(_ input: String) -> String {
        var result = input
        let allowed = CharacterSet(charactersIn: "0123456789.")
        let chars = CharacterSet(charactersIn: result)
        if !allowed.isSuperset(of: chars) {
            result = result.components(separatedBy: allowed.inverted).joined()
        }

        let parts = result.components(separatedBy: ".")
        if parts.count > 2 {
            result = parts[0] + "." + parts.dropFirst().joined()
        }
        if parts.count == 2 && parts[1].count > 2 {
            result = parts[0] + "." + String(parts[1].prefix(2))
        }
        if result.hasPrefix(".") {
            result = "0" + result
        }
        return result
    }

    private func formatAmountForInput(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? ""
    }

    private func formatAmountForDisplay(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? ""
    }
}

private struct ExpensePresetGroup: Identifiable {
    let name: String
    let icon: String
    let items: [ExpensePreset]

    var id: String { name }
}

private struct ExpensePreset: Identifiable, Hashable {
    let name: String
    let icon: String

    var id: String { name }
}

private struct ExpenseInputCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.65), lineWidth: 0.75)
            }
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.24) : EvenlyStyle.indigo.opacity(0.06), radius: 14, y: 7)
    }
}

private extension View {
    func expenseInputCard() -> some View {
        modifier(ExpenseInputCardModifier())
    }
}

private struct ExpensePeoplePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var primaryBlue: Color {
        EvenlyStyle.brandBlueAccent
    }
    private var selectedFill: Color {
        EvenlyStyle.selectedBlueFill(colorScheme)
    }
    private var glassStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.white.opacity(0.72)
    }
    private var cardShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.28)
            : Color.black.opacity(0.08)
    }
    private var topGlow: Color {
        EvenlyStyle.brandBlueGlow(colorScheme)
    }
    private var avatarFill: Color {
        EvenlyStyle.avatarBlueFill(colorScheme, selected: false)
    }
    private var avatarSelectedFill: Color {
        EvenlyStyle.avatarBlueFill(colorScheme, selected: true)
    }

    let participants: [Person]
    @Binding var selectedPayerId: UUID?
    @Binding var selectedParticipantIds: Set<UUID>

    private var activeParticipants: [Person] {
        participants.filter(\.isActive)
    }

    private var payerCandidates: [Person] {
        activeParticipants.filter { person in
            selectedParticipantIds.contains(person.id) && canPay(person)
        }
    }

    private var selectedPayer: Person? {
        guard let selectedPayerId else { return nil }
        return payerCandidates.first { $0.id == selectedPayerId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    pickerStatusHeader
                    memberListCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background {
                ZStack(alignment: .top) {
                    Color(.systemGroupedBackground)
                    LinearGradient(
                        colors: [topGlow, Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("付款与参与人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        reconcilePayer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        reconcilePayer()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                reconcilePayer()
            }
            .onChange(of: selectedParticipantIds) { _, _ in
                reconcilePayer()
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedParticipantIds)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedPayerId)
        }
    }

    private var pickerStatusHeader: some View {
        HStack(spacing: 12) {
            summaryPill(icon: "person.2.fill", text: "\(selectedParticipantIds.count) 人参与")
            summaryPill(icon: "creditcard.fill", text: selectedPayer.map { "\($0.name) 付款" } ?? "未选付款人")
        }
    }

    private func summaryPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary.opacity(0.74))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(glassStroke, lineWidth: 0.75)
            }
    }

    private var memberListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if participants.isEmpty {
                Text("请先在账本中添加成员")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            } else {
                ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                    memberCell(participant)
                    if index < participants.count - 1 {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(glassStroke, lineWidth: 0.75)
        }
        .shadow(color: cardShadow, radius: 22, y: 8)
    }

    private func memberCell(_ participant: Person) -> some View {
        let selectable = participant.isActive
        let isSelected = selectedParticipantIds.contains(participant.id)
        let isPayer = selectedPayerId == participant.id
        return Button {
            guard selectable else { return }
            toggleParticipant(participant)
        } label: {
            HStack(spacing: 14) {
                avatar(for: participant, isSelected: isSelected, isPayer: isPayer)

                VStack(alignment: .leading, spacing: 3) {
                    Text(participant.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectable ? .primary : .secondary)
                    Text(participantSubtitle(participant, isSelected: isSelected))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(primaryBlue)
                            .transition(.scale.combined(with: .opacity))
                    }

                    payerControl(for: participant, isPayer: isPayer)
                }
            }
            .frame(minHeight: 70)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isSelected ? selectedFill : Color.clear,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(selectable ? 1 : 0.48)
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
    }

    @ViewBuilder
    private func payerControl(for participant: Person, isPayer: Bool) -> some View {
        if canPay(participant) {
            Button {
                selectedParticipantIds.insert(participant.id)
                selectedPayerId = participant.id
                HapticManager.selection.selectionChanged()
            } label: {
                if isPayer {
                    Label("付款人", systemImage: "creditcard.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(primaryBlue.opacity(colorScheme == .dark ? 0.18 : 0.10), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(primaryBlue.opacity(0.55), lineWidth: 1)
                        }
                        .matchedGeometryEffect(id: "payerBadge", in: payerBadgeNamespace)
                } else {
                    Image(systemName: "creditcard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isPayer ? primaryBlue : .secondary)
                        .frame(width: 34, height: 34)
                        .background(Color(.tertiarySystemFill).opacity(colorScheme == .dark ? 0.85 : 1), in: Circle())
                }
            }
            .buttonStyle(.plain)
        }
    }

    @Namespace private var payerBadgeNamespace

    private func avatar(for person: Person, isSelected: Bool, isPayer: Bool = false) -> some View {
        RemoteAvatarView(
            avatarUrl: person.avatarUrl,
            fallbackText: person.name,
            size: 48,
            fallbackBackground: isPayer ? primaryBlue : (isSelected ? avatarSelectedFill : avatarFill),
            fallbackForeground: isPayer ? .white : primaryBlue
        )
        .overlay {
            Circle()
                .stroke(
                    isPayer ? primaryBlue : (isSelected ? primaryBlue.opacity(0.42) : glassStroke.opacity(0.65)),
                    lineWidth: isPayer ? 2 : 1
                )
        }
        .overlay(alignment: .bottomTrailing) {
            if isPayer {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(primaryBlue, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(.systemGroupedBackground), lineWidth: 2)
                    }
                    .offset(x: 2, y: 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .shadow(
            color: isPayer ? primaryBlue.opacity(colorScheme == .dark ? 0.30 : 0.18) : Color.clear,
            radius: isPayer ? 8 : 0,
            y: isPayer ? 4 : 0
        )
    }

    private func toggleParticipant(_ participant: Person) {
        if selectedParticipantIds.contains(participant.id) {
            selectedParticipantIds.remove(participant.id)
        } else {
            selectedParticipantIds.insert(participant.id)
            if selectedPayerId == nil, canPay(participant) {
                selectedPayerId = participant.id
            }
        }
        reconcilePayer()
        HapticManager.impact(.light)
    }

    private func removeParticipant(_ participant: Person) {
        selectedParticipantIds.remove(participant.id)
        reconcilePayer()
        HapticManager.impact(.light)
    }

    private func reconcilePayer() {
        if let selectedPayerId,
           payerCandidates.contains(where: { $0.id == selectedPayerId }) {
            return
        }
        selectedPayerId = payerCandidates.first?.id
    }

    private func participantSubtitle(_ participant: Person, isSelected: Bool) -> String {
        if participant.isPending { return "邀请中" }
        if selectedPayerId == participant.id { return "付款人" }
        if participant.isTemporary { return isSelected ? "已参与 · 临时" : "临时" }
        return isSelected ? "已参与" : "未参与"
    }

    private func canPay(_ person: Person) -> Bool {
        person.isActive && !person.isTemporary && (person.userId?.isEmpty == false)
    }
}

@MainActor
private final class VoiceExpenseRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false

    private var recorder: AVAudioRecorder?
    private let synthesizer = AVSpeechSynthesizer()

    func start() async throws {
        guard await Self.requestRecordPermission() else {
            throw NSError(
                domain: "VoiceExpense",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "请在系统设置中允许麦克风权限"]
            )
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio)
        try session.setActive(true)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("evenly-voice-\(UUID().uuidString).m4a")
        recorder = try AVAudioRecorder(
            url: url,
            settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
        )
        recorder?.record()
        isRecording = true
    }

    nonisolated private static func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func stop() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        return recorder.url
    }

    func cancel() {
        guard let recorder else { return }
        recorder.stop()
        try? FileManager.default.removeItem(at: recorder.url)
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(utterance)
    }
}

#Preview {
    AddExpenseView(participants: [
        Person(name: "张三"),
        Person(name: "李四"),
        Person(name: "王五")
    ]) { _ in .success(()) }
}
