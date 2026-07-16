//
//  LedgerShareCardView.swift
//  Evenly
//
//  Shareable ledger summary card (image) for WeChat / Weibo / system share sheet.
//

import SwiftUI
import Charts
import UIKit

// MARK: - Share section options

/// Blocks the user can include on the share image.
enum LedgerShareSection: String, CaseIterable, Identifiable, Codable, Hashable {
    case totalOutflow
    case billCount
    case members
    case transfers
    case expenseDetails

    var id: String { rawValue }

    var title: String {
        switch self {
        case .totalOutflow: return "支出"
        case .billCount: return "账单数"
        case .members: return "成员"
        case .transfers: return "转账流向"
        case .expenseDetails: return "账单明细"
        }
    }

    var subtitle: String {
        switch self {
        case .totalOutflow: return "结算总支出金额"
        case .billCount: return "计入结算的账单笔数"
        case .members: return "账本成员人数"
        case .transfers: return "谁应转给谁多少"
        case .expenseDetails: return "各笔账单标题与金额"
        }
    }

    var systemImage: String {
        switch self {
        case .totalOutflow: return "yensign.circle.fill"
        case .billCount: return "doc.text.fill"
        case .members: return "person.2.fill"
        case .transfers: return "arrow.left.arrow.right"
        case .expenseDetails: return "list.bullet.rectangle.fill"
        }
    }

    /// Default selection when user has never customized.
    static var defaultSelection: Set<LedgerShareSection> {
        [.totalOutflow, .billCount, .members, .transfers, .expenseDetails]
    }
}

struct LedgerShareOptions {
    private static let storageKey = "evenly.share.selectedSections"

    static func load() -> Set<LedgerShareSection> {
        guard let raw = UserDefaults.standard.array(forKey: storageKey) as? [String] else {
            return LedgerShareSection.defaultSelection
        }
        let parsed = Set(raw.compactMap(LedgerShareSection.init(rawValue:)))
        return parsed.isEmpty ? LedgerShareSection.defaultSelection : parsed
    }

    static func save(_ sections: Set<LedgerShareSection>) {
        UserDefaults.standard.set(sections.map(\.rawValue).sorted(), forKey: storageKey)
    }
}

// MARK: - Snapshot data

struct LedgerShareSnapshot: Identifiable {
    let id = UUID()

    struct TransferRow: Identifiable {
        let id: String
        let fromName: String
        let toName: String
        let amount: Decimal
        let includesUnconfirmed: Bool
    }

    struct ExpenseRow: Identifiable {
        let id: UUID
        let title: String
        let amount: Decimal
        let payerName: String
        /// Participants who share the bill (names, order preserved).
        let participantNames: [String]
        let isPending: Bool

        /// Compact subtitle: 付款 + 参与
        var peopleSummary: String {
            let participantsLabel: String
            if participantNames.isEmpty {
                participantsLabel = "—"
            } else if participantNames.count <= 4 {
                participantsLabel = participantNames.joined(separator: "、")
            } else {
                let head = participantNames.prefix(3).joined(separator: "、")
                participantsLabel = "\(head) 等\(participantNames.count)人"
            }
            return "付款 \(payerName) · 参与 \(participantsLabel)"
        }
    }

    let ledgerTitle: String
    let totalOutflow: Decimal
    let expenseCount: Int
    let memberCount: Int
    let transfers: [TransferRow]
    let expenseDetails: [ExpenseRow]
    let generatedAt: Date

    static func build(
        ledger: Ledger,
        settlements: [Settlement],
        balanceResults: [(Person, Decimal)] = []
    ) -> LedgerShareSnapshot {
        // Align with settlement / ledger confirmation setting.
        let expenses = ledger.settlementExpenses
        let total = expenses.reduce(Decimal.zero) { $0 + $1.netAmount }

        let transfers = settlements
            .filter { $0.amount > 0 }
            .map {
                TransferRow(
                    id: $0.id,
                    fromName: $0.fromUserName,
                    toName: $0.toUserName,
                    amount: $0.amount,
                    includesUnconfirmed: $0.includesUnconfirmed
                )
            }
            .sorted { $0.amount > $1.amount }

        // Newest first for明细; cap so the share image stays readable.
        let details = expenses
            .sorted {
                ($0.expenseDate ?? .distantPast) > ($1.expenseDate ?? .distantPast)
            }
            .prefix(12)
            .map { expense in
                ExpenseRow(
                    id: expense.id,
                    title: expense.title.isEmpty ? "未命名" : expense.title,
                    amount: expense.netAmount,
                    payerName: expense.payer.name,
                    participantNames: expense.participants.map(\.name),
                    isPending: expense.status == .pending
                )
            }

        return LedgerShareSnapshot(
            ledgerTitle: ledger.title,
            totalOutflow: total,
            expenseCount: expenses.count,
            memberCount: ledger.participantCount,
            transfers: Array(transfers.prefix(10)),
            expenseDetails: Array(details),
            generatedAt: Date()
        )
    }
}

// MARK: - Share card (exportable)

struct LedgerShareCardView: View {
    let snapshot: LedgerShareSnapshot
    let sections: Set<LedgerShareSection>
    /// Fixed light palette so shares look consistent in dark mode devices.
    private let cardWidth: CGFloat = 390

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if showsAnyStat {
                statsRow
            }
            if sections.contains(.transfers), !snapshot.transfers.isEmpty {
                transfersSection
            } else if sections.contains(.transfers), snapshot.transfers.isEmpty {
                emptySection(
                    title: "转账流向",
                    systemImage: "arrow.left.arrow.right",
                    message: "当前无需转账（已结清或暂无结算账单）"
                )
            }
            if sections.contains(.expenseDetails), !snapshot.expenseDetails.isEmpty {
                expenseDetailsSection
            } else if sections.contains(.expenseDetails), snapshot.expenseDetails.isEmpty {
                emptySection(
                    title: "账单明细",
                    systemImage: "list.bullet.rectangle",
                    message: "暂无计入结算的账单"
                )
            }
            footer
        }
        .padding(22)
        .frame(width: cardWidth, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.92, green: 0.95, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(EvenlyStyle.brandBlue.opacity(0.12))
                .frame(width: 140, height: 140)
                .offset(x: 40, y: -50)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: EvenlyStyle.brandBlue.opacity(0.18), radius: 24, y: 12)
    }

    private var showsAnyStat: Bool {
        sections.contains(.totalOutflow)
            || sections.contains(.billCount)
            || sections.contains(.members)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Evenly 账本小结")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EvenlyStyle.brandBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(EvenlyStyle.brandBlue.opacity(0.12), in: Capsule())
                Text(snapshot.ledgerTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.24))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(EvenlyStyle.brandBlue.opacity(0.85))
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            if sections.contains(.totalOutflow) {
                shareStat(title: "支出", value: money(snapshot.totalOutflow), accent: true)
            }
            if sections.contains(.billCount) {
                shareStat(title: "账单", value: "\(snapshot.expenseCount)", accent: false)
            }
            if sections.contains(.members) {
                shareStat(title: "成员", value: "\(snapshot.memberCount)", accent: false)
            }
        }
    }

    private func shareStat(title: String, value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(accent ? Color.white.opacity(0.8) : Color.secondary)
            Text(value)
                .font(.system(size: accent ? 20 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? Color.white : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            if accent {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [EvenlyStyle.brandBlueHero, EvenlyStyle.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.88))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
        }
    }

    private var transfersSection: some View {
        let hasProvisional = snapshot.transfers.contains(where: \.includesUnconfirmed)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                sectionTitle("转账流向", systemImage: "arrow.left.arrow.right")
                if hasProvisional {
                    unconfirmedBadge
                }
            }
            if hasProvisional {
                Text("灰色条目含未确认账单，确认后金额不变")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(snapshot.transfers) { row in
                    let provisional = row.includesUnconfirmed
                    let accent = provisional ? Color.secondary : EvenlyStyle.brandBlue
                    HStack(spacing: 8) {
                        Text(row.fromName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(provisional ? Color.secondary : Color.primary)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                        Text(row.toName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(provisional ? Color.secondary : Color.primary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if provisional {
                            Text("未确认")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                        Text(money(row.amount))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        accent.opacity(provisional ? 0.08 : 0.07),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var expenseDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("账单明细", systemImage: "list.bullet.rectangle")
            VStack(spacing: 0) {
                ForEach(Array(snapshot.expenseDetails.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(
                                        row.isPending
                                        ? Color.secondary
                                        : Color(red: 0.15, green: 0.2, blue: 0.3)
                                    )
                                    .lineLimit(1)
                                if row.isPending {
                                    unconfirmedBadge
                                }
                            }
                            Text(row.peopleSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Text(money(row.amount))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(row.isPending ? Color.secondary : EvenlyStyle.brandBlue)
                    }
                    .padding(.vertical, 10)
                    if index < snapshot.expenseDetails.count - 1 {
                        Divider().opacity(0.35)
                    }
                }
            }
            if snapshot.expenseCount > snapshot.expenseDetails.count {
                Text("仅展示最近 \(snapshot.expenseDetails.count) 笔 · 共 \(snapshot.expenseCount) 笔")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var unconfirmedBadge: some View {
        Text("未确认")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private func emptySection(title: String, systemImage: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title, systemImage: systemImage)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Text("由 Evenly 生成 · \(dateString(snapshot.generatedAt))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("evenly")
                .font(.caption2.weight(.bold))
                .foregroundStyle(EvenlyStyle.brandBlue.opacity(0.7))
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color(red: 0.15, green: 0.2, blue: 0.3))
    }

    private func money(_ amount: Decimal) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: n) ?? "¥0"
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }
}

// MARK: - Share sheet with section picker

struct LedgerShareSheet: View {
    let snapshot: LedgerShareSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSections: Set<LedgerShareSection> = LedgerShareOptions.load()
    @State private var shareImage: UIImage?
    @State private var isRendering = true
    @State private var showShare = false
    @State private var errorMessage: String?
    @State private var renderTask: Task<Void, Never>?

    private var canShare: Bool {
        !selectedSections.isEmpty && shareImage != nil && !isRendering
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sectionPicker

                    if let shareImage {
                        Image(uiImage: shareImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                            .padding(.horizontal, 16)
                            .animation(.easeInOut(duration: 0.2), value: selectedSections)
                    } else if isRendering {
                        ProgressView("生成预览…")
                            .padding(.top, 40)
                    } else if let errorMessage {
                        ContentUnavailableView(
                            "生成失败",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                    }

                    Text("勾选想展示的内容，预览会自动更新；再点右上角分享到微信、微博等")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("分享账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showShare = true
                        HapticManager.impact(.medium)
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!canShare)
                }
            }
            .onAppear { scheduleRender() }
            .onChange(of: selectedSections) { _, newValue in
                LedgerShareOptions.save(newValue)
                scheduleRender()
            }
            .sheet(isPresented: $showShare) {
                if let shareImage {
                    ShareActivityView(
                        items: [
                            shareImage,
                            shareCaption,
                        ]
                    )
                }
            }
            .onDisappear {
                renderTask?.cancel()
            }
        }
    }

    private var sectionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("展示内容")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(selectedSections.count == LedgerShareSection.allCases.count ? "清空" : "全选") {
                    if selectedSections.count == LedgerShareSection.allCases.count {
                        selectedSections = []
                    } else {
                        selectedSections = Set(LedgerShareSection.allCases)
                    }
                    HapticManager.selectionChanged()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(EvenlyStyle.brandBlue)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(LedgerShareSection.allCases) { section in
                    let isOn = selectedSections.contains(section)
                    Button {
                        toggle(section)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.systemImage)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isOn ? EvenlyStyle.brandBlue : .secondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(section.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isOn ? EvenlyStyle.brandBlue : Color.secondary.opacity(0.45))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if section != LedgerShareSection.allCases.last {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

            if selectedSections.isEmpty {
                Text("至少选择一项，才能生成分享图")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
    }

    private var shareCaption: String {
        var parts = ["【Evenly】\(snapshot.ledgerTitle)"]
        if selectedSections.contains(.totalOutflow) {
            parts.append("支出 \(formatPlain(snapshot.totalOutflow))")
        }
        if selectedSections.contains(.billCount) {
            parts.append("\(snapshot.expenseCount) 笔账单")
        }
        return parts.joined(separator: " · ")
    }

    private func toggle(_ section: LedgerShareSection) {
        if selectedSections.contains(section) {
            selectedSections.remove(section)
        } else {
            selectedSections.insert(section)
        }
        HapticManager.selectionChanged()
    }

    private func scheduleRender() {
        renderTask?.cancel()
        guard !selectedSections.isEmpty else {
            shareImage = nil
            isRendering = false
            errorMessage = nil
            return
        }
        isRendering = true
        errorMessage = nil
        let sections = selectedSections
        let snap = snapshot
        renderTask = Task { @MainActor in
            // Debounce rapid toggles.
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            render(sections: sections, snapshot: snap)
        }
    }

    @MainActor
    private func render(sections: Set<LedgerShareSection>, snapshot: LedgerShareSnapshot) {
        isRendering = true
        errorMessage = nil
        let card = LedgerShareCardView(snapshot: snapshot, sections: sections)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale * 1.5
        if let image = renderer.uiImage {
            shareImage = image
            isRendering = false
            return
        }
        // Retry next runloop — ImageRenderer sometimes needs a layout pass.
        DispatchQueue.main.async {
            guard !Task.isCancelled else { return }
            let retry = ImageRenderer(content: card)
            retry.scale = 3
            if let image = retry.uiImage {
                shareImage = image
            } else {
                errorMessage = "无法生成图片，请稍后重试"
                shareImage = nil
            }
            isRendering = false
        }
    }

    private func formatPlain(_ amount: Decimal) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "¥0"
    }
}

struct ShareActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = excludedActivityTypes
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
