import SwiftUI
import PhotosUI
import UIKit

struct ReceiptPreviewItem: Identifiable {
    let id = UUID()
    var image: UIImage? = nil
    var url: String? = nil
    var expenseId: UUID? = nil
}

enum ReceiptImageSource {
    /// Keep signed URLs intact and request a fresh one each time an image is loaded.
    static func downloadURL(receiptURL: String, expenseId: UUID,
                            authorize: ((UUID, String) async throws -> String)? = nil) async throws -> URL {
        let raw: String
        if let authorize {
            raw = try await authorize(expenseId, receiptURL)
        } else {
            let response: ReceiptDownloadURLResponse = try await APIClient.shared.get(
                APIEndpoints.receiptDownloadURL(expenseId: expenseId, receiptURL: receiptURL)
            )
            raw = response.url
        }
        guard let url = URL(string: raw), url.scheme == "https", url.host != nil else {
            throw APIError.invalidURL
        }
        return url
    }

    static func load(receiptURL: String?, expenseId: UUID?) async throws -> UIImage {
        guard let receiptURL, let expenseId else { throw APIError.invalidURL }
        let url = try await downloadURL(receiptURL: receiptURL, expenseId: expenseId)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(statusCode: http.statusCode, data: data)
        }
        guard let image = UIImage(data: data) else { throw APIError.invalidResponse }
        return image
    }
}

enum ReceiptImagePrep {
    static func jpegData(from image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let factor = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let prepared = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = prepared.jpegData(compressionQuality: 0.85), data.count <= 5 * 1024 * 1024 else { return nil }
        return data
    }
}

struct ExpenseReceiptPicker: View {
    @Binding var urls: [String]
    @Binding var images: [Data]
    @Binding var isLoading: Bool
    var isSaving: Bool
    var expenseId: UUID? = nil
    @State private var selection: [PhotosPickerItem] = []
    @State private var preview: ReceiptPreviewItem?
    @State private var error: String?
    private var count: Int { urls.count + images.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("凭据（\(count)/3）").font(.headline)
                Spacer()
                if isLoading { ProgressView() }
            }
            Text("可选，支持发票、付款截图或收据，最多 3 张图片。")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    receiptTile {
                        Button { preview = ReceiptPreviewItem(url: url, expenseId: expenseId) } label: {
                            ReceiptThumbnail(url: url, expenseId: expenseId)
                        }
                    } remove: { urls.remove(at: index) }
                }
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    receiptTile {
                        Button { preview = ReceiptPreviewItem(image: UIImage(data: data)) } label: {
                            if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
                        }
                    } remove: { images.remove(at: index) }
                }
                if count < 3 {
                    PhotosPicker(selection: $selection, maxSelectionCount: 3 - count, matching: .images) {
                        VStack(spacing: 5) {
                            Image(systemName: "plus").font(.title3)
                            Text("添加图片").font(.caption)
                        }
                        .frame(width: 80, height: 96)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isLoading || isSaving)
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        .sheet(item: $preview) { item in ReceiptPreviewView(item: item) }
    }

    private func receiptTile<Content: View>(@ViewBuilder content: () -> Content, remove: @escaping () -> Void) -> some View {
        content().buttonStyle(.plain)
            .frame(width: 80, height: 96).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.65))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("移除凭据")
                .disabled(isLoading || isSaving)
            }
    }

    @MainActor
    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        error = nil
        defer { isLoading = false; selection = [] }
        for item in items.prefix(max(0, 3 - count)) {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data), let jpeg = ReceiptImagePrep.jpegData(from: image) else {
                    error = "部分图片无法读取或处理，请重新选择。"
                    continue
                }
                images.append(jpeg)
            } catch { self.error = "图片读取失败，请重新选择。" }
        }
    }
}

struct ReceiptThumbnail: View {
    let url: String
    let expenseId: UUID?
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else if failed { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary) }
            else { ProgressView() }
        }
        .frame(width: 80, height: 96)
        .background(Color.secondary.opacity(0.08)).clipped()
        .task(id: url) {
            image = nil
            failed = false
            do { image = try await ReceiptImageSource.load(receiptURL: url, expenseId: expenseId) }
            catch { if !Task.isCancelled { failed = true } }
        }
    }
}

struct ExpenseReceiptGallery: View {
    let urls: [String]
    let expenseId: UUID
    @State private var preview: ReceiptPreviewItem?
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                Button { preview = ReceiptPreviewItem(url: url, expenseId: expenseId) } label: {
                    ReceiptThumbnail(url: url, expenseId: expenseId).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain).accessibilityLabel("查看凭据图片 \(index + 1)")
            }
        }
        .padding(.vertical, 4)
        .sheet(item: $preview) { item in ReceiptPreviewView(item: item) }
    }
}

struct ReceiptPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let item: ReceiptPreviewItem
    @State private var image: UIImage?
    @State private var failed = false
    @State private var attempt = 0
    var body: some View {
        NavigationStack {
            Group {
                if let image = image ?? item.image { ReceiptZoomView(image: image) }
                else if failed {
                    ContentUnavailableView {
                        Label("图片加载失败", systemImage: "photo.badge.exclamationmark")
                    } actions: { Button("重试") { failed = false; attempt += 1 } }
                } else { ProgressView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("凭据").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .task(id: attempt) {
                guard item.image == nil else { return }
                do {
                    image = try await ReceiptImageSource.load(receiptURL: item.url, expenseId: item.expenseId)
                } catch { if !Task.isCancelled { failed = true } }
            }
        }
    }
}

private struct ReceiptZoomView: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ReceiptZoomScrollView {
        let view = ReceiptZoomScrollView()
        view.minimumZoomScale = 1
        view.maximumZoomScale = 5
        view.delegate = context.coordinator
        view.imageView.image = image
        return view
    }
    func updateUIView(_ view: ReceiptZoomScrollView, context: Context) { view.imageView.image = image }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ReceiptZoomScrollView)?.imageView }
    }
}

private final class ReceiptZoomScrollView: UIScrollView {
    let imageView = UIImageView()
    private var lastSize: CGSize = .zero
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastSize {
            lastSize = bounds.size
            setZoomScale(1, animated: false)
            imageView.frame = CGRect(origin: .zero, size: bounds.size)
            contentSize = bounds.size
        }
    }
}
