//
//  AddExpenseView.swift
//  Evenly
//
//  Created by alex_yehui on 2025/12/14.
//  Modern expense input with animations and haptics
//

import SwiftUI
@preconcurrency import AVFoundation
import Combine

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var selectedPayerId: UUID?
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var isSaving = false
    @State private var transcript: String?
    @State private var errorMessage: String?
    @State private var selectedPresetId: String?
    @State private var selectedPresetGroupId: String = "餐饮"
    @State private var selectedCategory: String?
    @State private var selectedIcon: ExpenseIcon?
    @State private var isPeoplePickerPresented = false
    @State private var isIconPickerPresented = false
    @StateObject private var voiceSession = VoiceExpenseStreamingSession()
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
    private var selectedPreset: ExpenseCategoryPreset? {
        ExpenseCategoryCatalog.categories.flatMap(\.items).first { $0.id == selectedPresetId }
    }
    private var selectedPresetGroup: ExpenseCategoryGroup {
        ExpenseCategoryCatalog.categories.first { $0.id == selectedPresetGroupId } ?? ExpenseCategoryCatalog.categories[0]
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
    private var voiceTranscriptText: String? {
        let liveText = [voiceSession.finalTranscript, voiceSession.partialTranscript]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !liveText.isEmpty {
            return liveText
        }
        if !voiceSession.statusMessage.isEmpty {
            return voiceSession.statusMessage
        }
        return transcript
    }
    private var shouldShowVoiceGuidance: Bool {
        existingId == nil
            && ledgerId != nil
            && voiceTranscriptText == nil
            && !voiceSession.isRecording
            && !voiceSession.isProcessing
    }
    private let voiceInputExamples = [
        "我和Tristan住宿花了 300，是我付的",
        "晚餐 268，Sylvia付，我、Stella和Tristan平摊",
        "打车 78，Tristan付的，我和Tristan各 39",
    ]

    init(
        expense: Expense? = nil,
        participants: [Person],
        currentUserId: String? = nil,
        ledgerId: UUID? = nil,
        onSave: @escaping @MainActor (Expense) async -> Result<Void, Error>
    ) {
        self.participants = participants
        self.currentUserId = currentUserId
        self.ledgerId = ledgerId
        self.onSave = onSave
        self.existingId = expense?.id
        _title = State(initialValue: expense?.title ?? "")
        _selectedCategory = State(initialValue: expense?.category)
        _selectedIcon = State(initialValue: expense?.icon)
        if let preset = expense.flatMap({ ExpenseCategoryCatalog.preset(named: $0.title) }) {
            _selectedPresetId = State(initialValue: preset.id)
            _selectedPresetGroupId = State(initialValue: preset.category)
        }
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
            .scrollDismissesKeyboard(.interactively)
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
            .sheet(isPresented: $isIconPickerPresented) {
                ExpenseIconPickerView(selection: Binding(
                    get: { selectedIcon },
                    set: { icon in
                        selectedIcon = icon
                        if selectedCategory == nil {
                            selectedCategory = selectedPresetGroup.name
                        }
                    }
                ))
                .presentationDetents([.medium, .large])
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
                voiceSession.cancel()
            }
            .onReceive(voiceSession.$draft.compactMap { $0 }) { draft in
                applyVoiceDraft(draft)
            }
            .onReceive(voiceSession.$errorMessage.compactMap { $0 }) { message in
                errorMessage = message
                HapticManager.notificationOccurred(.error)
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("金额", systemImage: "yensign.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if existingId == nil, ledgerId != nil {
                    voiceIconButton
                }
                if let selectedIcon {
                    HStack(spacing: 6) {
                        expenseIconView(selectedIcon, size: 14)
                        Text(selectedCategory ?? selectedPreset?.name ?? "自定义")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ExpenseChrome.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        ExpenseChrome.accent.opacity(colorScheme == .dark ? 0.18 : 0.1),
                        in: Capsule()
                    )
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("¥")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
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

            if let voiceText = voiceTranscriptText {
                Text(voiceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if shouldShowVoiceGuidance {
                voiceGuidanceView
            }

            HStack {
                Text(
                    splitAmountText.map { "约 ¥\($0) / 人" }
                        ?? "先填金额，再选择谁一起分"
                )
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
                    .fill(voiceSession.isRecording ? Color.red.opacity(colorScheme == .dark ? 0.22 : 0.14) : primaryBlue.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 36, height: 36)
                if voiceSession.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: voiceSession.isRecording ? "stop.fill" : "mic.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(voiceSession.isRecording ? .red : primaryBlue)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(voiceSession.isProcessing)
        .accessibilityLabel(voiceSession.isRecording ? "停止并生成草稿" : "语音记账")
    }

    private var voiceGuidanceView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("试试这样说", systemImage: "quote.bubble.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryBlue)
            ForEach(voiceInputExamples, id: \.self) { example in
                Text(example)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("类别", systemImage: "square.grid.5x5.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCategoryCatalog.categories) { group in
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

            Button {
                focusedField = nil
                isIconPickerPresented = true
            } label: {
                HStack {
                    if let selectedIcon {
                        expenseIconView(selectedIcon, size: 18)
                    } else {
                        Image(systemName: "face.smiling")
                    }
                    Text("选择其他图标或 Emoji")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
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

    private func presetGroupButton(_ group: ExpenseCategoryGroup) -> some View {
        let isSelected = selectedPresetGroup.id == group.id
        return Button {
            focusedField = nil
            selectedPresetGroupId = group.id
            selectedCategory = group.name
            if !group.items.contains(where: { $0.id == selectedPresetId }) {
                selectedPresetId = nil
                selectedIcon = group.icon
            }
            HapticManager.selection.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: group.icon.value)
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

    private func presetButton(_ preset: ExpenseCategoryPreset) -> some View {
        let isSelected = selectedPresetId == preset.id
        return Button {
            focusedField = nil
            selectedPresetId = preset.id
            title = preset.name
            selectedCategory = preset.category
            selectedIcon = preset.icon
            HapticManager.selection.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: preset.icon.value)
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
        if isLocked {
            return "付款人，必须参与"
        }
        return isSelected ? "已参与分摊" : "点按加入分摊"
    }

    private func initials(for participant: Person) -> String {
        String(participant.name.prefix(1))
    }

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
        if voiceSession.isRecording {
            voiceSession.stop()
            return
        }

        guard let ledgerId else { return }
        transcript = nil
        Task {
            do {
                try await voiceSession.start(ledgerId: ledgerId)
            } catch {
                await MainActor.run {
                    errorMessage = APIError.friendlyNetworkMessage(for: error)
                    HapticManager.notificationOccurred(.error)
                }
            }
        }
    }

    private func applyVoiceDraft(_ draft: VoiceExpenseDraft) {
        title = draft.title
        amountText = formatAmountForInput(draft.amount)
        transcript = draft.transcript
        if let category = draft.category,
           let icon = ExpenseCategoryCatalog.defaultIcon(for: category) {
            selectedCategory = category
            selectedIcon = icon
            selectedPresetGroupId = category
        }
        if let payer = registeredParticipants.first(where: { $0.userId == draft.payerUserId }) {
            selectedPayerId = payer.id
        }
        selectedParticipantIds = Set(
            draft.participantMemberIds.compactMap(UUID.init(uuidString:))
        )
        if let selectedPayerId {
            selectedParticipantIds.insert(selectedPayerId)
        }
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
            participants: Array(selectedParticipants),
            category: selectedCategory,
            icon: selectedIcon
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
    @ViewBuilder
    private func expenseIconView(_ icon: ExpenseIcon, size: CGFloat) -> some View {
        if icon.type == .emoji {
            Text(icon.value).font(.system(size: size))
        } else {
            Image(systemName: icon.value).font(.system(size: size, weight: .semibold))
        }
    }
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

private struct ExpenseIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: ExpenseIcon?
    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    iconSection("图标", icons: ExpenseCategoryCatalog.sfSymbolIcons)
                    iconSection("Emoji", icons: ExpenseCategoryCatalog.emojiIcons)
                }
                .padding(20)
            }
            .navigationTitle("选择账单图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func iconSection(_ title: String, icons: [ExpenseIcon]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(icons) { icon in
                    Button {
                        selection = icon
                        HapticManager.selection.selectionChanged()
                    } label: {
                        Group {
                            if icon.type == .emoji {
                                Text(icon.value).font(.system(size: 24))
                            } else {
                                Image(systemName: icon.value).font(.system(size: 20, weight: .semibold))
                            }
                        }
                        .frame(width: 48, height: 48)
                        .foregroundStyle(selection == icon ? .white : EvenlyStyle.brandBlueAccent)
                        .background(selection == icon ? EvenlyStyle.brandBlueAccent : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon.value)
                }
            }
        }
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
            summaryPill(
                icon: "creditcard.fill",
                text: selectedPayer.map { "\($0.name) 付款" } ?? "未选付款人"
            )
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
        if selectedPayerId == participant.id {
            return "付款人"
        }
        if participant.isTemporary { return isSelected ? "已参与 · 临时" : "临时" }
        return isSelected ? "已参与" : "未参与"
    }

    private func canPay(_ person: Person) -> Bool {
        person.isActive && !person.isTemporary && (person.userId?.isEmpty == false)
    }
}

@MainActor
private final class VoiceExpenseStreamingSession: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isProcessing = false
    @Published private(set) var partialTranscript = ""
    @Published private(set) var finalTranscript = ""
    @Published private(set) var statusMessage = ""
    @Published var draft: VoiceExpenseDraft?
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var audioSendTask: Task<Void, Never>?
    private var audioStream: AsyncStream<Data>?
    private var audioStreamContinuation: AsyncStream<Data>.Continuation?
    private var audioConverter: AVAudioConverter?
    private var targetAudioFormat: AVAudioFormat?
    private var silenceDetector = VoiceSilenceDetector(silenceDuration: 1.8)

    func start(ledgerId: UUID) async throws {
        guard await Self.requestRecordPermission() else {
            throw NSError(
                domain: "VoiceExpense",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "请在系统设置中允许麦克风权限"]
            )
        }

        resetState()
        statusMessage = "正在连接语音识别..."
        try configureAudioEngine()
        let task = try APIClient.shared.webSocketTask(
            endpoint: APIEndpoints.voiceExpenseSession(ledgerId: ledgerId.uuidString)
        )
        webSocketTask = task
        task.resume()
        receiveTask = Task { [weak self] in
            await self?.receiveMessages()
        }
        // 音频发送走独立后台串行 Task，避免在主线程 await send 被 UI 渲染阻塞，
        // 造成 stop 信号排在最后一个音频 chunk 之后多秒才能发出。
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self)
        audioStream = stream
        audioStreamContinuation = continuation
        audioSendTask = Task { [weak self] in
            for await data in stream {
                guard let self, let ws = self.webSocketTask else { break }
                if Task.isCancelled { break }
                try? await ws.send(.data(data))
            }
        }
        try await sendStartMessage()
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            task.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
            stopAudioEngine()
            throw error
        }
    }

    nonisolated private static func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func stop(automatically: Bool = false) {
        guard isRecording else { return }
        stopAudioEngine()
        isRecording = false
        isProcessing = true
        statusMessage = automatically ? "检测到停顿，正在完成识别..." : "正在识别并生成草稿..."
        Task { [weak self] in
            try? await self?.sendJSON(["type": "stop"])
        }
    }

    func cancel() {
        stopAudioEngine()
        receiveTask?.cancel()
        receiveTask = nil
        audioSendTask?.cancel()
        audioSendTask = nil
        audioStreamContinuation?.finish()
        audioStreamContinuation = nil
        audioStream = nil
        if let task = webSocketTask {
            webSocketTask = nil
            Task {
                if let data = try? JSONSerialization.data(withJSONObject: ["type": "cancel"]),
                   let text = String(data: data, encoding: .utf8) {
                    try? await task.send(.string(text))
                }
                task.cancel(with: .normalClosure, reason: nil)
            }
        }
        isRecording = false
        isProcessing = false
        statusMessage = ""
    }

    private func resetState() {
        cancel()
        silenceDetector = VoiceSilenceDetector(silenceDuration: 1.8)
        partialTranscript = ""
        finalTranscript = ""
        statusMessage = ""
        draft = nil
        errorMessage = nil
    }

    private func configureAudioEngine() throws {
        let session = AVAudioSession.sharedInstance()
        // Use allowBluetooth for Xcode 16 / iOS 18 SDK (CI). allowBluetoothHFP is only
        // available on newer SDKs and fails to compile on macos-15 runners.
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {   
            throw NSError(
                domain: "VoiceExpense",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "当前麦克风输入格式不可用"]
            )
        }
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(
                domain: "VoiceExpense",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "无法初始化语音编码器"]
            )
        }
        audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard let converter = audioConverter else {
            throw NSError(
                domain: "VoiceExpense",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "无法初始化语音编码器"]
            )
        }
        targetAudioFormat = targetFormat

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let data = Self.pcm16Data(from: buffer, converter: converter, targetFormat: targetFormat), !data.isEmpty else {
                return
            }
            let levelDB = VoiceSilenceDetector.rmsDB(pcm16: data)
            let duration = Double(data.count / MemoryLayout<Int16>.size) / targetFormat.sampleRate
            Task { @MainActor [weak self] in
                self?.observeAudioLevel(levelDB, duration: duration)
            }
            // 直接丢给后台串行发送流，不要在 MainActor 上 await send —— 否则被 UI 渲染阻塞
            // 会导致 stop 信号在最后一个 chunk 后排几秒才能发出去，拖慢整条链路。
            self?.audioStreamContinuation?.yield(data)
        }
    }

    private func observeAudioLevel(_ levelDB: Double, duration: TimeInterval) {
        guard isRecording else { return }
        if silenceDetector.observe(levelDB: levelDB, duration: duration) {
            stop(automatically: true)
        }
    }

    private func stopAudioEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioConverter = nil
        targetAudioFormat = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func sendStartMessage() async throws {
        try await sendJSON([
            "type": "start",
            "audio": [
                "format": "pcm_s16le",
                "sample_rate": 16_000,
                "channels": 1,
            ],
        ])
    }

    private func sendJSON(_ payload: [String: Any]) async throws {
        guard let webSocketTask else { throw APIError.invalidResponse }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(decoding: data, as: UTF8.self)
        try await webSocketTask.send(.string(text))
    }

    private func receiveMessages() async {
        guard let webSocketTask else { return }
        do {
            while !Task.isCancelled {
                let message = try await webSocketTask.receive()
                switch message {
                case .string(let text):
                    handleEvent(Data(text.utf8))
                case .data(let data):
                    handleEvent(data)
                @unknown default:
                    break
                }
            }
        } catch {
            if isRecording || isProcessing {
                errorMessage = APIError.friendlyNetworkMessage(for: error)
                isRecording = false
                isProcessing = false
                stopAudioEngine()
            }
        }
    }

    private func handleEvent(_ data: Data) {
        guard let event = try? JSONDecoder().decode(VoiceExpenseSessionEvent.self, from: data) else {
            return
        }
        switch event.type {
        case "ready":
            statusMessage = "正在录音..."
            return
        case "partial_transcript":
            statusMessage = ""
            partialTranscript = event.text ?? ""
        case "final_transcript":
            statusMessage = ""
            partialTranscript = ""
            finalTranscript = [finalTranscript, event.text ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case "draft":
            isRecording = false
            isProcessing = false
            statusMessage = ""
            stopAudioEngine()
            draft = event.data
            audioSendTask?.cancel()
            audioSendTask = nil
            audioStreamContinuation?.finish()
            audioStreamContinuation = nil
            audioStream = nil
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
        case "error":
            isRecording = false
            isProcessing = false
            statusMessage = ""
            stopAudioEngine()
            errorMessage = event.message ?? "语音识别失败"
            audioSendTask?.cancel()
            audioSendTask = nil
            audioStreamContinuation?.finish()
            audioStreamContinuation = nil
            audioStream = nil
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
        default:
            return
        }
    }

    nonisolated private static func pcm16Data(
        from buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> Data? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 32
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            return nil
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, conversionError == nil, convertedBuffer.frameLength > 0, let samples = convertedBuffer.floatChannelData?[0] else {
            return nil
        }

        var data = Data(capacity: Int(convertedBuffer.frameLength) * MemoryLayout<Int16>.size)
        for index in 0..<Int(convertedBuffer.frameLength) {
            let clamped = max(-1, min(1, samples[index]))
            var sample = Int16(clamped * Float(Int16.max))
            withUnsafeBytes(of: &sample) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }
}

private struct VoiceExpenseSessionEvent: Decodable {
    let type: String
    let text: String?
    let message: String?
    let data: VoiceExpenseDraft?
}

#Preview {
    AddExpenseView(participants: [
        Person(name: "张三"),
        Person(name: "李四"),
        Person(name: "王五")
    ]) { _ in .success(()) }
}
