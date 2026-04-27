//
//  DataManagementView.swift
//  Evenly
//
//  Created by alex_yehui on 2025/12/14.
//

import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @EnvironmentObject var ledgerStore: LedgerStore
    @State private var isExporting = false
    @State private var isClearingCache = false
    @State private var showingSuccessAlert = false
    @State private var showingClearAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        List {
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("导出所有账本", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(isExporting || ledgerStore.ledgers.isEmpty)
            } header: {
                Text("导出数据")
            } footer: {
                Text("将所有账本数据导出为文本文件")
            }

            Section {
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    HStack {
                        Label("清除本地缓存", systemImage: "trash")
                        Spacer()
                        if isClearingCache {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(isClearingCache)
            } header: {
                Text("存储")
            } footer: {
                Text("清除本地缓存不会删除云端数据")
            }

            Section {
                HStack {
                    Label("账本数量", systemImage: "book.closed")
                        .font(.subheadline)
                    Spacer()
                    Text("\(ledgerStore.ledgers.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("账单总数", systemImage: "list.bullet.rectangle")
                        .font(.subheadline)
                    Spacer()
                    Text("\(ledgerStore.ledgers.reduce(0) { $0 + $1.expenses.count })")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("参与者总数", systemImage: "person.2")
                        .font(.subheadline)
                    Spacer()
                    Text("\(ledgerStore.ledgers.reduce(0) { $0 + $1.participants.count })")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("统计")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("数据管理")
        .alert("清除缓存", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("确定要清除本地缓存吗？")
        }
        .alert(alertTitle, isPresented: $showingSuccessAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: getExportDocument(),
            contentType: .plainText,
            defaultFilename: "Evenly_Export"
        ) { result in
            switch result {
            case .success(let url):
                alertTitle = "导出成功"
                alertMessage = "数据已保存至：\(url.lastPathComponent)"
                showingSuccessAlert = true
            case .failure(let error):
                alertTitle = "导出失败"
                alertMessage = error.localizedDescription
                showingSuccessAlert = true
            }
        }
    }

    private func exportData() {
        isExporting = true
    }

    private func getExportDocument() -> TextFile {
        var text = "Evenly 导出\n"
        text += "==========\n\n"

        for ledger in ledgerStore.ledgers {
            text += "【\(ledger.title)】\n"
            if !ledger.participants.isEmpty {
                text += "成员：\(ledger.participants.map(\.name).joined(separator: ", "))\n"
            }
            if !ledger.expenses.isEmpty {
                text += "账单：\n"
                for expense in ledger.expenses {
                    text += "  • \(expense.title)：\(formatAmount(expense.amount))"
                    text += "（\(expense.payer.name) 支付）\n"
                }
            } else {
                text += "暂无账单\n"
            }
            text += "\n"
        }

        return TextFile(content: text)
    }

    private func clearCache() {
        isClearingCache = true
        UserDefaults.standard.removeObject(forKey: "CachedLedgers")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isClearingCache = false
            alertTitle = "完成"
            alertMessage = "本地缓存已清除。"
            showingSuccessAlert = true
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 0
        return formatter.string(from: number) ?? "¥0"
    }
}

struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: content.data(using: .utf8)!)
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
            .environmentObject(LedgerStore())
    }
}
