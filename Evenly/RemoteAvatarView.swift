import SwiftUI

struct RemoteAvatarView: View {
    let avatarUrl: String?
    var localImage: UIImage? = nil
    var fallbackText: String = "?"
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.14))

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
        return URL(string: avatarUrl)
    }

    private var fallback: some View {
        Text(String(fallbackText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.blue)
    }
}
