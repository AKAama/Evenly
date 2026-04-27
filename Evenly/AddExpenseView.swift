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
    @State private var selectedPayer: Person?
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var isSaving = false

    let participants: [Person]
    var onSave: (Expense) -> Void
    private let existingId: UUID?
    private var registeredParticipants: [Person] {
        participants.filter { participant in
            !participant.isTemporary && participant.userId?.isEmpty == false
        }
    }

    init(expense: Expense? = nil, participants: [Person], onSave: @escaping (Expense) -> Void) {
        self.participants = participants
        self.onSave = onSave
        self.existingId = expense?.id
        _title = State(initialValue: expense?.title ?? "")
        if let amount = expense?.amount {
            _amountText = State(initialValue: formatAmountForInput(amount))
        }
        _selectedPayer = State(initialValue: expense?.payer)
        _selectedParticipantIds = State(initialValue: Set(expense?.participants.map(\.id) ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账单名称") {
                    TextField("输入账单名称", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("金额") {
                    HStack {
                        Text("¥")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
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
                        Picker("选择付款人", selection: $selectedPayer) {
                            ForEach(registeredParticipants) { participant in
                                Text(participant.name).tag(participant as Person?)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedPayer) { _, newPayer in
                            if let newPayer {
                                selectedParticipantIds.insert(newPayer.id)
                            }
                            HapticManager.impact(.light)
                        }
                    }
                }

                Section("参与人") {
                    if registeredParticipants.isEmpty {
                        Text("临时成员暂不支持参与账单分摊")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(registeredParticipants) { participant in
                            HStack {
                                Text(participant.name)
                                    .dynamicTypeSize(.accessibility2)
                                Spacer()
                                if selectedParticipantIds.contains(participant.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleParticipant(participant)
                            }
                        }
                        .onAppear {
                            if selectedPayer == nil, let first = registeredParticipants.first {
                                selectedPayer = first
                            }
                            if selectedParticipantIds.isEmpty, let first = registeredParticipants.first {
                                selectedParticipantIds.insert(first.id)
                            }
                        }
                    }
                }
            }
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
                    Button("保存") {
                        saveExpense()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                HapticManager.prepare()
                if selectedPayer == nil, let first = registeredParticipants.first {
                    selectedPayer = first
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
        if selectedPayer?.id == participant.id {
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
        guard let amount = Decimal(string: amountText),
              !title.isEmpty,
              let payer = selectedPayer,
              payer.userId?.isEmpty == false else { return }

        selectedParticipantIds.insert(payer.id)
        let selectedParticipants = registeredParticipants.filter { selectedParticipantIds.contains($0.id) }
        guard !selectedParticipants.isEmpty else { return }

        HapticManager.notificationOccurred(.success)

        let expense = Expense(
            id: existingId ?? UUID(),
            title: title,
            amount: amount,
            payer: payer,
            participants: Array(selectedParticipants)
        )
        onSave(expense)
        dismiss()
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
    ]) { _ in }
}
