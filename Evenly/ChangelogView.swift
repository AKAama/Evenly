import SwiftUI

struct ChangelogEntry: Decodable, Identifiable {
    let id: String
    let version: String?
    let date: String
    let title: String
    let items: [String]

    static let all: [ChangelogEntry] = {
        do {
            return try load()
        } catch {
            NSLog("Failed to load changelog: %@", error.localizedDescription)
            return []
        }
    }()

    static func load(from bundle: Bundle = .main) throws -> [ChangelogEntry] {
        guard let url = bundle.url(forResource: "changelog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([ChangelogEntry].self, from: Data(contentsOf: url))
    }
}

struct ChangelogView: View {
    var body: some View {
        List(ChangelogEntry.all) { entry in
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.title)
                        .font(.headline)
                    ForEach(entry.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    if let version = entry.version {
                        Text("版本 \(version)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Text(entry.date)
                }
                .textCase(nil)
            }
        }
        .overlay {
            if ChangelogEntry.all.isEmpty {
                ContentUnavailableView(
                    "暂时无法显示更新日志",
                    systemImage: "clock.arrow.circlepath"
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("更新日志")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ChangelogView() }
}
