//
//  LedgerDrawerView.swift
//  Evenly
//
//  Bookshelf-style ledger browser (inspired by Apple Books).
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Cover palette (stable per ledger id)

enum LedgerBookCoverStyle {
    /// Soft, book-like cloth/paper tones — not pure brand blue so the shelf feels warm.
    private static let palettes: [(Color, Color)] = [
        (Color(red: 0.18, green: 0.32, blue: 0.55), Color(red: 0.10, green: 0.20, blue: 0.38)),
        (Color(red: 0.42, green: 0.22, blue: 0.28), Color(red: 0.28, green: 0.12, blue: 0.16)),
        (Color(red: 0.20, green: 0.40, blue: 0.36), Color(red: 0.10, green: 0.26, blue: 0.24)),
        (Color(red: 0.48, green: 0.34, blue: 0.18), Color(red: 0.32, green: 0.20, blue: 0.10)),
        (Color(red: 0.30, green: 0.24, blue: 0.48), Color(red: 0.18, green: 0.14, blue: 0.32)),
        (Color(red: 0.22, green: 0.36, blue: 0.48), Color(red: 0.12, green: 0.22, blue: 0.32)),
        (Color(red: 0.40, green: 0.28, blue: 0.22), Color(red: 0.26, green: 0.16, blue: 0.12)),
        (Color(red: 0.16, green: 0.38, blue: 0.42), Color(red: 0.08, green: 0.24, blue: 0.28)),
    ]

    static func colors(for id: UUID) -> (Color, Color) {
        let idx = abs(id.uuidString.hashValue) % palettes.count
        return palettes[idx]
    }
}

// MARK: - Single book cover

struct LedgerBookCover: View {
    let ledger: Ledger
    var isCurrent: Bool = false
    /// Slightly smaller for dense shelves.
    var compact: Bool = false
    /// Optional local preview while uploading.
    var localCoverImage: UIImage? = nil

    private var palette: (Color, Color) {
        LedgerBookCoverStyle.colors(for: ledger.id)
    }

    private var hasCustomCover: Bool {
        localCoverImage != nil || !(ledger.coverUrl ?? "").isEmpty
    }

    var body: some View {
        let corner: CGFloat = compact ? 5 : 6
        VStack(spacing: compact ? 8 : 10) {
            ZStack(alignment: .bottom) {
                // Cover board (generated style or custom image)
                ZStack {
                    generatedCoverFill
                    coverImageLayer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay {
                    // Darken bottom for title legibility on photos
                    if hasCustomCover {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.05),
                                        Color.black.opacity(0.55),
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.14),
                                        Color.clear,
                                        Color.black.opacity(0.18),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .overlay(alignment: .leading) {
                    // Spine highlight
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.05),
                                    Color.black.opacity(0.15),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: compact ? 5 : 7)
                        .padding(.leading, 5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.22), radius: 8, y: 5)
                .shadow(color: palette.1.opacity(0.35), radius: 12, y: 8)

                // Cover content
                VStack(spacing: 0) {
                    Spacer(minLength: 8)
                    Text(ledger.title)
                        .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, compact ? 10 : 12)
                    Spacer(minLength: 6)
                    Text("\(ledger.memberCount) 人 · \(ledger.expenseCount) 笔")
                        .font(.system(size: compact ? 9 : 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                        .padding(.bottom, compact ? 10 : 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isCurrent {
                    VStack {
                        HStack {
                            Spacer()
                            Text("当前")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(palette.1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.92), in: Capsule())
                                .padding(7)
                        }
                        Spacer()
                    }
                }
            }
            .aspectRatio(0.68, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(ledger.title)，\(ledger.memberCount) 人，\(ledger.expenseCount) 笔账单\(isCurrent ? "，当前账本" : "")")
        }
    }

    @ViewBuilder
    private var coverImageLayer: some View {
        if let localCoverImage {
            Image(uiImage: localCoverImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let url = EvenlyMediaURL.resolve(ledger.coverUrl) {
            // id forces reload when cover changes; fill frame so AsyncImage is not zero-sized.
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.clear
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(url.absoluteString)
        }
    }

    private var generatedCoverFill: some View {
        LinearGradient(
            colors: [palette.0, palette.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - COS / CDN URL normalization (avatars + covers)

enum EvenlyMediaURL {
    /// Prefer the public COS endpoint when the custom CDN host has cert/access issues.
    static func resolve(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        guard var components = URLComponents(string: raw) else { return nil }
        // Historical / CDN host — same object path on the bucket endpoint.
        if components.host == "cos.ismyh.cn" {
            components.host = "evenly-1325650734.cos.ap-nanjing.myqcloud.com"
            if components.scheme == nil {
                components.scheme = "https"
            }
        }
        return components.url
    }
}

// MARK: - Shelf strip under a row of books

private struct BookshelfStrip: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            // Shelf edge (thickness)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [
                                Color(red: 0.28, green: 0.22, blue: 0.18),
                                Color(red: 0.18, green: 0.14, blue: 0.12),
                            ]
                            : [
                                Color(red: 0.78, green: 0.66, blue: 0.52),
                                Color(red: 0.62, green: 0.48, blue: 0.36),
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 11)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35))
                        .frame(height: 1.5)
                }
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)

            // Soft lip highlight
            Capsule()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.2))
                .frame(height: 2)
                .padding(.horizontal, 6)
                .offset(y: 1)
        }
        .padding(.top, 2)
    }
}

// MARK: - Ownership filter

enum LedgerOwnershipFilter: String, CaseIterable, Identifiable {
    case all
    case owned
    case joined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .owned: return "我创建的"
        case .joined: return "我加入的"
        }
    }

    func includes(_ ledger: Ledger, userId: String?) -> Bool {
        guard let userId, !userId.isEmpty else { return true }
        switch self {
        case .all: return true
        case .owned: return ledger.ownerId == userId
        case .joined: return ledger.ownerId != userId
        }
    }
}

// MARK: - Shared bookshelf grid

struct LedgerBookshelfView: View {
    let ledgers: [Ledger]
    let currentId: UUID?
    var onSelect: (Ledger) -> Void
    var onDelete: ((Ledger) -> Void)? = nil
    var canDelete: ((Ledger) -> Bool)? = nil
    /// Owner-only: change bookshelf cover (same COS flow as avatars).
    var onSetCover: ((Ledger) -> Void)? = nil
    var onClearCover: ((Ledger) -> Void)? = nil
    var emptyTitle: String = "还没有账本"
    var emptyMessage: String = "创建一个账本，邀请朋友一起记账"
    var showsSearchEmpty: Bool = false
    /// Optional filter chip row (全部 / 我创建的 / 我加入的).
    var ownershipFilter: Binding<LedgerOwnershipFilter>? = nil
    var currentUserId: String? = nil

    private let booksPerShelf = 3

    private var visibleLedgers: [Ledger] {
        guard let filter = ownershipFilter?.wrappedValue else { return ledgers }
        return ledgers.filter { filter.includes($0, userId: currentUserId) }
    }

    /// Chunk into rows so each shelf strip sits under a real row of covers.
    private var shelves: [[Ledger]] {
        stride(from: 0, to: visibleLedgers.count, by: booksPerShelf).map { start in
            Array(visibleLedgers[start..<min(start + booksPerShelf, visibleLedgers.count)])
        }
    }

    var body: some View {
        Group {
            if ledgers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        if let ownershipFilter {
                            filterBar(ownershipFilter)
                        }

                        if visibleLedgers.isEmpty {
                            filterEmptyState
                                .padding(.top, 40)
                        } else {
                            ForEach(Array(shelves.enumerated()), id: \.offset) { _, row in
                                shelfRow(row)
                            }

                            Text("轻点打开 · 长按可设置封面或管理")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                                .padding(.bottom, 24)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
        }
        .background(bookshelfBackground)
    }

    private func filterBar(_ binding: Binding<LedgerOwnershipFilter>) -> some View {
        Picker("筛选", selection: binding) {
            ForEach(LedgerOwnershipFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("账本筛选")
    }

    private var filterEmptyState: some View {
        let filter = ownershipFilter?.wrappedValue ?? .all
        let message: String = {
            switch filter {
            case .all: return emptyMessage
            case .owned: return "还没有你创建的账本"
            case .joined: return "还没有加入别人的账本"
            }
        }()
        return VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    private func shelfRow(_ row: [Ledger]) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(row) { ledger in
                    bookButton(ledger)
                        .frame(maxWidth: .infinity)
                }
                // Keep incomplete last shelf aligned left with empty slots.
                if row.count < booksPerShelf {
                    ForEach(0..<(booksPerShelf - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)

            BookshelfStrip()
        }
    }

    private func bookButton(_ ledger: Ledger) -> some View {
        Button {
            HapticManager.impact(.light)
            onSelect(ledger)
        } label: {
            LedgerBookCover(
                ledger: ledger,
                isCurrent: ledger.id == currentId
            )
        }
        .buttonStyle(BookPressStyle())
        .contextMenu {
            Button {
                HapticManager.impact(.medium)
                onSelect(ledger)
            } label: {
                Label("打开账本", systemImage: "book.fill")
            }
            if canDelete?(ledger) == true {
                if let onSetCover {
                    Button {
                        HapticManager.impact(.light)
                        onSetCover(ledger)
                    } label: {
                        Label("设置封面", systemImage: "photo.on.rectangle.angled")
                    }
                }
                if let onClearCover, !(ledger.coverUrl ?? "").isEmpty {
                    Button {
                        HapticManager.impact(.light)
                        onClearCover(ledger)
                    } label: {
                        Label("恢复默认封面", systemImage: "arrow.uturn.backward")
                    }
                }
            }
            if canDelete?(ledger) == true, let onDelete {
                Button(role: .destructive) {
                    HapticManager.notificationOccurred(.warning)
                    onDelete(ledger)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(showsSearchEmpty ? "未找到账本" : emptyTitle, systemImage: "books.vertical")
        } description: {
            Text(showsSearchEmpty ? "试试其他关键词" : emptyMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bookshelfBackground)
    }

    private var bookshelfBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)
            // Soft warm wash like a reading room
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.93, blue: 0.88).opacity(0.55),
                    Color.clear,
                    EvenlyStyle.brandBlue.opacity(0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

/// Press-down scale like picking a book off the shelf.
private struct BookPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .brightness(configuration.isPressed ? -0.03 : 0)
    }
}

// MARK: - Drawer sheet

struct LedgerDrawerView: View {
    @EnvironmentObject var ledgerStore: LedgerStore
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var ledgerToDelete: Ledger?
    @State private var coverTarget: Ledger?
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var isUploadingCover = false
    @State private var coverError: String?
    @State private var ownershipFilter: LedgerOwnershipFilter = .all

    let showingAddLedger: () -> Void

    private var filteredLedgers: [Ledger] {
        if searchText.isEmpty {
            return ledgerStore.ledgers
        }
        return ledgerStore.ledgers.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LedgerBookshelfView(
                    ledgers: filteredLedgers,
                    currentId: ledgerStore.currentLedger?.id,
                    onSelect: { ledger in
                        ledgerStore.setCurrentLedger(ledger)
                        dismiss()
                    },
                    onDelete: { ledger in
                        ledgerToDelete = ledger
                        showingDeleteConfirmation = true
                    },
                    canDelete: { $0.ownerId == auth.user?.id },
                    onSetCover: { ledger in
                        coverTarget = ledger
                    },
                    onClearCover: { ledger in
                        clearCover(ledger)
                    },
                    showsSearchEmpty: isFiltering && filteredLedgers.isEmpty,
                    ownershipFilter: $ownershipFilter,
                    currentUserId: auth.user?.id
                )

                if isUploadingCover {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("上传封面…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .searchable(text: $searchText, prompt: "搜索账本")
            .navigationTitle("账本")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.impact(.medium)
                        showingAddLedger()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.spring(.light))
                    .accessibilityLabel("新建账本")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        HapticManager.impact(.light)
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "确认删除",
                isPresented: $showingDeleteConfirmation,
                message: "确定要删除账本 \"\(ledgerToDelete?.title ?? "")\" 吗？",
                confirmTitle: "删除",
                destructive: true
            ) {
                if let ledger = ledgerToDelete {
                    ledgerStore.deleteLedger(ledger)
                }
            }
            .photosPicker(
                isPresented: Binding(
                    get: { coverTarget != nil },
                    set: { if !$0 { coverTarget = nil } }
                ),
                selection: $coverPickerItem,
                matching: .images
            )
            .onChange(of: coverPickerItem) { _, item in
                guard let item, let target = coverTarget else { return }
                Task { await loadAndUploadCover(item: item, ledger: target) }
            }
            .alert("封面上传失败", isPresented: Binding(
                get: { coverError != nil },
                set: { if !$0 { coverError = nil } }
            )) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(coverError ?? "")
            }
        }
    }

    private func clearCover(_ ledger: Ledger) {
        isUploadingCover = true
        ledgerStore.clearLedgerCover(ledger) { result in
            isUploadingCover = false
            switch result {
            case .success:
                HapticManager.notificationOccurred(.success)
            case .failure(let error):
                coverError = error.localizedDescription
                HapticManager.notificationOccurred(.error)
            }
        }
    }

    @MainActor
    private func loadAndUploadCover(item: PhotosPickerItem, ledger: Ledger) async {
        isUploadingCover = true
        coverError = nil
        defer {
            coverPickerItem = nil
            coverTarget = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                coverError = "无法读取图片"
                isUploadingCover = false
                return
            }
            // Portrait-ish book ratio crop-center, compress like avatars.
            let prepared = LedgerCoverImagePrep.jpegData(from: image) ?? data
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                ledgerStore.uploadLedgerCover(ledger, imageData: prepared) { result in
                    isUploadingCover = false
                    switch result {
                    case .success:
                        HapticManager.notificationOccurred(.success)
                    case .failure(let error):
                        coverError = error.localizedDescription
                        HapticManager.notificationOccurred(.error)
                    }
                    cont.resume()
                }
            }
        } catch {
            isUploadingCover = false
            coverError = error.localizedDescription
        }
    }
}

// MARK: - Shared cover image prep (create + bookshelf)

enum LedgerCoverImagePrep {
    /// Center-crop toward ~2:3 and JPEG-compress (same idea as avatar pipeline).
    static func jpegData(from image: UIImage, maxEdge: CGFloat = 1200) -> Data? {
        let targetRatio: CGFloat = 2.0 / 3.0 // width / height
        let size = image.size
        guard size.width > 1, size.height > 1 else {
            return image.jpegData(compressionQuality: 0.82)
        }
        let current = size.width / size.height
        var crop = CGRect(origin: .zero, size: size)
        if current > targetRatio {
            let newW = size.height * targetRatio
            crop.origin.x = (size.width - newW) / 2
            crop.size.width = newW
        } else if current < targetRatio {
            let newH = size.width / targetRatio
            crop.origin.y = (size.height - newH) / 2
            crop.size.height = newH
        }
        guard let cg = image.cgImage?.cropping(to: CGRect(
            x: crop.origin.x * image.scale,
            y: crop.origin.y * image.scale,
            width: crop.size.width * image.scale,
            height: crop.size.height * image.scale
        )) else {
            return image.jpegData(compressionQuality: 0.82)
        }
        var cropped = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        let longest = max(cropped.size.width, cropped.size.height)
        if longest > maxEdge {
            let scale = maxEdge / longest
            let newSize = CGSize(width: cropped.size.width * scale, height: cropped.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            cropped = renderer.image { _ in
                cropped.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        return cropped.jpegData(compressionQuality: 0.82)
    }
}

/// Full-screen bookshelf used when no current ledger is selected.
struct LedgerPickerBookshelf: View {
    @EnvironmentObject private var ledgerStore: LedgerStore
    @EnvironmentObject private var auth: AuthManager
    let searchText: String
    var onClearSearch: () -> Void = {}
    @State private var ownershipFilter: LedgerOwnershipFilter = .all

    private var items: [Ledger] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return ledgerStore.ledgers }
        return ledgerStore.ledgers.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        LedgerBookshelfView(
            ledgers: items,
            currentId: ledgerStore.currentLedger?.id,
            onSelect: { ledger in
                onClearSearch()
                ledgerStore.setCurrentLedger(ledger)
            },
            emptyTitle: "选择一本账本",
            emptyMessage: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "创建账本后会出现在这里"
                : "没有匹配的账本",
            showsSearchEmpty: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && items.isEmpty,
            ownershipFilter: $ownershipFilter,
            currentUserId: auth.user?.id
        )
    }
}

#Preview {
    LedgerDrawerView(showingAddLedger: {})
        .environmentObject(LedgerStore())
        .environmentObject(AuthManager())
}
