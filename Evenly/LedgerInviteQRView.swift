//
//  LedgerInviteQRView.swift
//  Evenly
//
//  Owner-facing QR / share sheet for ledger invite Universal Links.
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct LedgerInviteQRView: View {
    @EnvironmentObject var ledgerStore: LedgerStore
    @Environment(\.dismiss) private var dismiss

    let ledgerId: UUID

    @State private var link: LedgerInviteLinkResponse?
    @State private var isLoading = true
    @State private var isRotating = false
    @State private var errorMessage: String?
    @State private var copied = false

    private var ledgerTitle: String {
        ledgerStore.ledger(id: ledgerId)?.title ?? link?.ledgerName ?? "账本"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("朋友用 iPhone 相机扫一扫，可直接打开 Evenly 加入「\(ledgerTitle)」")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if isLoading && link == nil {
                        ProgressView("生成邀请码…")
                            .padding(.vertical, 48)
                    } else if let link {
                        qrCard(for: link)

                        ShareLink(item: URL(string: link.url) ?? URL(string: "https://app.ismyh.cn")!) {
                            Label("分享邀请链接", systemImage: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(EvenlyStyle.brandBlue)

                        Button {
                            UIPasteboard.general.string = link.url
                            copied = true
                            HapticManager.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copied = false
                            }
                        } label: {
                            Label(copied ? "已复制" : "复制链接", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            rotateLink()
                        } label: {
                            if isRotating {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            } else {
                                Label("重置二维码", systemImage: "arrow.triangle.2.circlepath")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .disabled(isRotating)

                        Text("重置后旧二维码立即失效。仅账本创建者可生成与重置。")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("邀请二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await loadLink() }
        }
    }

    private func qrCard(for link: LedgerInviteLinkResponse) -> some View {
        VStack(spacing: 14) {
            if let image = QRCodeGenerator.image(from: link.url, dimension: 240) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            } else {
                Text("无法生成二维码")
                    .foregroundStyle(.secondary)
            }

            Text(link.url)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
        }
    }

    @MainActor
    private func loadLink() async {
        isLoading = true
        errorMessage = nil
        do {
            link = try await ledgerStore.fetchInviteLink(ledgerId: ledgerId)
            HapticManager.notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notificationOccurred(.error)
        }
        isLoading = false
    }

    private func rotateLink() {
        isRotating = true
        errorMessage = nil
        Task {
            do {
                let next = try await ledgerStore.rotateInviteLink(ledgerId: ledgerId)
                await MainActor.run {
                    link = next
                    isRotating = false
                    HapticManager.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRotating = false
                    HapticManager.notificationOccurred(.error)
                }
            }
        }
    }
}

enum QRCodeGenerator {
    static func image(from string: String, dimension: CGFloat) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scale = dimension / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
