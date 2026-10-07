import SwiftUI
import UIKit

struct LedgerCoverSelection: Identifiable {
    let id = UUID()
    let image: UIImage
    var ledger: Ledger? = nil
}

/// Shared geometry for the preview and the saved image.
enum LedgerCoverCrop {
    static let aspectRatio: CGFloat = 2.0 / 3.0

    static func imageFrame(imageSize: CGSize, viewport: CGSize, zoom: CGFloat, offset: CGSize) -> CGRect {
        let fill = max(viewport.width / imageSize.width, viewport.height / imageSize.height) * min(max(zoom, 1), 4)
        let size = CGSize(width: imageSize.width * fill, height: imageSize.height * fill)
        let limitX = max(0, (size.width - viewport.width) / 2)
        let limitY = max(0, (size.height - viewport.height) / 2)
        let x = min(max(offset.width, -limitX), limitX)
        let y = min(max(offset.height, -limitY), limitY)
        return CGRect(x: (viewport.width - size.width) / 2 + x,
                      y: (viewport.height - size.height) / 2 + y,
                      width: size.width, height: size.height)
    }

    static func render(image: UIImage, viewport: CGSize, zoom: CGFloat, offset: CGSize) -> UIImage {
        let frame = imageFrame(imageSize: image.size, viewport: viewport, zoom: zoom, offset: offset)
        let output = CGSize(width: 800, height: 1200)
        let factor = output.width / viewport.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: output, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: output))
            image.draw(in: CGRect(x: frame.minX * factor, y: frame.minY * factor,
                                  width: frame.width * factor, height: frame.height * factor))
        }
    }
}

struct LedgerCoverEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let onSave: (UIImage) -> Void
    @State private var zoom: CGFloat = 1
    /// Fractions of viewport dimensions keep the selection stable on rotation.
    @State private var position: CGSize = .zero
    @GestureState private var translation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1

    private var effectiveZoom: CGFloat { min(max(zoom * magnification, 1), 4) }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let width = min(340, max(100, geometry.size.width - 48), max(100, (geometry.size.height - 210) * LedgerCoverCrop.aspectRatio))
                let viewport = CGSize(width: width, height: width / LedgerCoverCrop.aspectRatio)
                ScrollView {
                    VStack(spacing: 20) {
                        cropPreview(viewport: viewport)
                            .padding(.top, 20)
                        Text("拖动调整位置，双指缩放。框内区域将作为账本封面。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Button { changeZoom(-0.25) } label: {
                                Image(systemName: "minus.magnifyingglass")
                                    .frame(width: 44, height: 44)
                            }
                            .disabled(zoom <= 1)
                            .accessibilityLabel("缩小封面")
                            Slider(value: $zoom, in: 1...4)
                                .accessibilityLabel("封面缩放")
                                .accessibilityValue("\(Int(zoom * 100))%")
                            Button { changeZoom(0.25) } label: {
                                Image(systemName: "plus.magnifyingglass")
                                    .frame(width: 44, height: 44)
                            }
                            .disabled(zoom >= 4)
                            .accessibilityLabel("放大封面")
                        }
                        .tint(EvenlyStyle.brandBlue)
                        .onChange(of: zoom) { _, _ in clampPosition(viewport: viewport) }
                        Button("重置", systemImage: "arrow.counterclockwise") {
                            zoom = 1
                            position = .zero
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("使用封面") {
                            onSave(LedgerCoverCrop.render(image: image, viewport: viewport,
                                                         zoom: effectiveZoom, offset: currentOffset(viewport)))
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("编辑封面")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func currentOffset(_ viewport: CGSize) -> CGSize {
        CGSize(width: position.width * viewport.width + translation.width,
               height: position.height * viewport.height + translation.height)
    }

    private func cropPreview(viewport: CGSize) -> some View {
        let frame = LedgerCoverCrop.imageFrame(imageSize: image.size, viewport: viewport,
                                              zoom: effectiveZoom, offset: currentOffset(viewport))
        return ZStack(alignment: .topLeading) {
            Color.black
            Image(uiImage: image)
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
        .overlay {
            Rectangle().strokeBorder(.white, lineWidth: 2)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($translation) { value, state, _ in state = value.translation }
                .onEnded { value in
                    position.width += value.translation.width / viewport.width
                    position.height += value.translation.height / viewport.height
                    clampPosition(viewport: viewport)
                }
                .simultaneously(with: MagnificationGesture()
                    .updating($magnification) { value, state, _ in state = value }
                    .onEnded { value in
                        zoom = min(max(zoom * value, 1), 4)
                        clampPosition(viewport: viewport)
                    })
        )
        .accessibilityLabel("封面裁剪预览")
    }

    private func changeZoom(_ change: CGFloat) { zoom = min(max(zoom + change, 1), 4) }

    private func clampPosition(viewport: CGSize) {
        let frame = LedgerCoverCrop.imageFrame(imageSize: image.size, viewport: viewport, zoom: zoom,
                                              offset: CGSize(width: position.width * viewport.width,
                                                             height: position.height * viewport.height))
        position = CGSize(width: (frame.midX - viewport.width / 2) / viewport.width,
                          height: (frame.midY - viewport.height / 2) / viewport.height)
    }
}
