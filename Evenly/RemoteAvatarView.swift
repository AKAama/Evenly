import SwiftUI

struct RemoteAvatarView: View {
    let avatarUrl: String?
    var localImage: UIImage? = nil
    var fallbackText: String = "?"
    var size: CGFloat = 44
    var fallbackBackground: Color = Color.blue.opacity(0.14)
    var fallbackForeground: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .fill(fallbackBackground)

            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = validURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("头像")
    }

    private var validURL: URL? {
        guard let avatarUrl, !avatarUrl.isEmpty else { return nil }
        guard var components = URLComponents(string: avatarUrl) else { return nil }

        // Historical avatar URLs used a custom COS domain whose certificate
        // may be unavailable. The object path is identical on the bucket's
        // official HTTPS endpoint, so old profiles remain readable.
        if components.host == "cos.ismyh.cn" {
            components.host = "evenly-1325650734.cos.ap-nanjing.myqcloud.com"
        }
        return components.url
    }

    private var fallback: some View {
        Text(String(fallbackText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(fallbackForeground)
    }
}
