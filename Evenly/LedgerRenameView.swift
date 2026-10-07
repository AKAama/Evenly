import SwiftUI

struct LedgerRenameView: View {
    @EnvironmentObject private var store: LedgerStore
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let ledgerId: UUID
    @State private var name: String
    @State private var isSaving = false
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    init(ledger: Ledger) {
        ledgerId = ledger.id
        _name = State(initialValue: ledger.title)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("账本名称") {
                    TextField("输入账本名称", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .disabled(isSaving)
                        .onSubmit { save() }
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("修改账本名称")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        if isSaving { ProgressView() }
                        else { Text("保存").fontWeight(.semibold) }
                    }
                    .disabled(isSaving || trimmedName.isEmpty || trimmedName == store.ledger(id: ledgerId)?.title)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private func save() {
        guard !isSaving, !trimmedName.isEmpty,
              let ledger = store.ledger(id: ledgerId),
              ledger.ownerId == auth.user?.id,
              trimmedName != ledger.title else { return }
        isSaving = true
        error = nil
        nameFocused = false
        store.updateLedgerSettings(ledger, name: trimmedName) { result in
            isSaving = false
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
                dismiss()
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
    }
}
