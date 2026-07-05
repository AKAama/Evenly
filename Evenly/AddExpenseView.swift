//
//  AddExpenseView.swift
//  Evenly
//
//  Created by alex_yehui on 2025/12/14.
//  Modern expense input with animations and haptics
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var selectedPayerId: UUID?
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case title
        case amount
    }

    let participants: [Person]
    let currentUserId: String?
    var onSave: @MainActor (Expense) async -> Result<Void, Error>
    private let existingId: UUID?
    private var registeredParticipants: [Person] {
        participants.filter { participant in
            !participant.isTemporary && participant.userId?.isEmpty == false
        }
    }
    private var selectedPayer: Person? {
        guard let selectedPayerId else { return nil }
        return registeredParticipants.first { $0.id == selectedPayerId }
    }

    init(expense: Expense? = nil, participants: [Person], currentUserId: String? = nil, onSave: @escaping @MainActor (Expense) async -> Result<Void, Error>) {
        self.participants = participants
        self.currentUserId = currentUserId
        self.onSave = onSave
        self.existingId = expense?.id
        _title = State(initialValue: expense?.title ?? "")
        if let amount = expense?.amount {
            _amountText = State(initialValue: formatAmountForInput(amount))
        }
        let defaultPayer = participants.first { $0.userId == currentUserId }
            ?? participants.first { !$0.isTemporary && $0.userId?.isEmpty == false }
        _selectedPayerId = State(initialValue: expense?.payer.id ?? defaultPayer?.id)
        _selectedParticipantIds = State(initialValue: Set(expense?.participants.map(\.id) ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账单名称") {
                    TextField("输入账单名称", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                }

                Section("金额") {
                    HStack {
                        Text("¥")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: amountText) { _, newValue in
                                amountText = formatAmountInput(newValue)
                                HapticManager.selection.selectionChanged()
                            }
                    }
                }

                Section("付款人") {
                    if registeredParticipants.isEmpty {
                        Text("请先在账本中添加已注册成员")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("选择付款人", selection: $selectedPayerId) {
                            ForEach(registeredParticipants) { participant in
                                Text(participant.name).tag(participant.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedPayerId) { _, newPayerId in
                            focusedField = nil
                            if let newPayerId {
                                selectedParticipantIds.insert(newPayerId)
                            }
                            HapticManager.impact(.light)
                        }
                    }
                }

                Section("参与人") {
                    if participants.isEmpty {
                        Text("请先在账本中添加成员")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(participants) { participant in
                            HStack {
                                Text(participant.name)
                                    .dynamicTypeSize(.accessibility2)
                                if participant.isTemporary {
                                    Text("临时")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                                if selectedParticipantIds.contains(participant.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                focusedField = nil
                                toggleParticipant(participant)
                            }
                        }
                        .onAppear {
                            if selectedPayerId == nil, let first = registeredParticipants.first(where: { $0.userId == currentUserId }) ?? registeredParticipants.first {
                                selectedPayerId = first.id
                            }
                            if selectedParticipantIds.isEmpty, let first = registeredParticipants.first {
                                selectedParticipantIds.insert(first.id)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedParticipantIds.count)
            .navigationTitle(existingId == nil ? "新建账单" : "编辑账单")
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
            }
        }
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
        let selectedParticipants = participants.filter { selectedParticipantIds.contains($0.id) }
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
}

#Preview {
    AddExpenseView(participants: [
        Person(name: "张三"),
        Person(name: "李四"),
        Person(name: "王五")
    ]) { _ in .success(()) }
}
