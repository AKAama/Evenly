//
//  PlatformConsoleView.swift
//  Evenly
//
//  Platform ops shell — visual language inspired by SAVO wallet:
//  light canvas, floating pill tab bar, soft cards, large numbers,
//  circular quick actions, black capsule CTAs.
//

import SwiftUI
import UIKit

// MARK: - SAVO-inspired tokens (platform shell only)

enum PlatformStyle {
    static let canvas = Color(red: 0.99, green: 0.99, blue: 1.0)
    static let card = Color.white
    static let cardMuted = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let textPrimary = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.60)
    static let textTertiary = Color(red: 0.70, green: 0.70, blue: 0.74)
    static let accentPurple = Color(red: 0.45, green: 0.28, blue: 0.98)
    static let accentPink = Color(red: 0.95, green: 0.35, blue: 0.55)
    static let accentGreen = Color(red: 0.20, green: 0.72, blue: 0.45)
    static let accentBlue = Color(red: 0.25, green: 0.55, blue: 0.98)
    static let accentOrange = Color(red: 1.0, green: 0.55, blue: 0.20)
    static let blackCTA = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let tabBarFill = Color.white
    static let tabSelectedPill = Color(red: 0.94, green: 0.94, blue: 0.96)
    static let hairline = Color.black.opacity(0.06)

    static let cardRadius: CGFloat = 22
    static let pillRadius: CGFloat = 999
    static let tabBarHeight: CGFloat = 64

    static func cardShadow() -> some View {
        Color.clear
    }
}

extension View {
    func platformCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .foregroundStyle(PlatformStyle.textPrimary)
            .background(PlatformStyle.card, in: RoundedRectangle(cornerRadius: PlatformStyle.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }

    func platformSoftCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .foregroundStyle(PlatformStyle.textPrimary)
            .background(PlatformStyle.cardMuted, in: RoundedRectangle(cornerRadius: PlatformStyle.cardRadius, style: .continuous))
    }

    func platformPressable() -> some View {
        buttonStyle(PlatformPressStyle())
    }

    /// Sheets presented from the ops shell should stay light even if app theme is dark.
    func platformLightChrome() -> some View {
        self
            .preferredColorScheme(.light)
            .tint(PlatformStyle.accentPurple)
    }
}

struct PlatformPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Root + floating tab bar

struct PlatformConsoleRootView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = 0

    private var tabAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.42, dampingFraction: 0.86)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PlatformStyle.canvas.ignoresSafeArea()

            // Content cross-fade so page change feels less abrupt next to the sliding pill.
            ZStack {
                tabContent(for: selectedTab)
                    .id(selectedTab)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 10)).combined(with: .scale(scale: 0.985)),
                                removal: .opacity.combined(with: .offset(y: -6))
                            )
                    )
            }
            .animation(tabAnimation, value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, PlatformStyle.tabBarHeight + 18)

            PlatformFloatingTabBar(
                selectedTab: $selectedTab,
                meInitial: String((auth.user?.resolvedDisplayName ?? auth.user?.username ?? "我").prefix(1)),
                animation: tabAnimation
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        // Ops shell is light-only. Re-assert here so sheets/nav chrome don't follow app dark theme.
        .preferredColorScheme(.light)
        .tint(PlatformStyle.accentPurple)
    }

    @ViewBuilder
    private func tabContent(for tab: Int) -> some View {
        switch tab {
        case 0:
            PlatformHomeView(selectedTab: $selectedTab)
        case 1:
            PlatformUsersView()
        case 2:
            PlatformLedgersView()
        case 3:
            NavigationStack {
                PlatformBadgesView()
            }
        default:
            PlatformMeView()
        }
    }
}

private struct PlatformFloatingTabBar: View {
    @Binding var selectedTab: Int
    var meInitial: String = "我"
    var animation: Animation = .spring(response: 0.42, dampingFraction: 0.86)

    @Namespace private var tabPillNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 首页 · 用户 · 账本 · 铭牌 · 我的
    private let items: [(icon: String, title: String)] = [
        ("house.fill", "首页"),
        ("person.2.fill", "用户"),
        ("books.vertical.fill", "账本"),
        ("person.text.rectangle", "铭牌"),
        ("person.fill", "我的"),
    ]

    private var meIndex: Int { items.count - 1 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                let selected = selectedTab == index
                Button {
                    guard selectedTab != index else { return }
                    withAnimation(animation) {
                        selectedTab = index
                    }
                    HapticManager.selection.selectionChanged()
                } label: {
                    VStack(spacing: 3) {
                        if index == meIndex {
                            Text(meInitial)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(PlatformStyle.accentPink, in: Circle())
                                .scaleEffect(selected ? 1.06 : 1.0)
                        } else {
                            Image(systemName: items[index].icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selected ? PlatformStyle.accentPurple : PlatformStyle.textTertiary)
                                .symbolEffect(.bounce, value: selected)
                                .scaleEffect(selected ? 1.08 : 1.0)
                        }
                        Text(items[index].title)
                            .font(.system(size: 9, weight: selected ? .semibold : .medium))
                            .foregroundStyle(
                                selected
                                    ? (index == meIndex ? PlatformStyle.accentPink : PlatformStyle.accentPurple)
                                    : PlatformStyle.textTertiary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    // Sliding selection pill (matched geometry = fluid hop between tabs)
                    .background {
                        if selected {
                            Capsule(style: .continuous)
                                .fill(PlatformStyle.tabSelectedPill)
                                .padding(.horizontal, 2)
                                .matchedGeometryEffect(id: "platformTabSelectionPill", in: tabPillNamespace)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(animation, value: selectedTab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(PlatformStyle.tabBarFill)
                .shadow(color: Color.black.opacity(0.08), radius: 20, y: 8)
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(PlatformStyle.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Home (stats + audit feed)

private struct PlatformHomeView: View {
    @EnvironmentObject var auth: AuthManager
    @Binding var selectedTab: Int
    @State private var appUserTotal = 0
    @State private var activeLedgerTotal = 0
    @State private var archivedLedgerTotal = 0
    @State private var orphanLedgerTotal = 0
    @State private var todayAuditTotal = 0
    @State private var todayTopActions: [(String, Int)] = []
    @State private var auditEvents: [AuditEventItem] = []
    @State private var badgeCatalogCount = 0
    @State private var unassignedBadgeUsers = 0
    @State private var isLoading = true

    private static let actionLabels: [String: String] = [
        "auth.login": "登录",
        "auth.register": "注册",
        "auth.apple_login": "Apple 登录",
        "ledger.create": "创建账本",
        "ledger.join_invite": "加入账本",
        "expense.create": "记一笔",
        "expense.refund": "退款",
        "expense.delete": "删除账单",
        "expense.confirmed": "确认账单",
        "expense.rejected": "拒绝账单",
        "settlement.create": "记录转账",
        "user.deactivate": "注销账号",
        "user.deactivate_admin": "管理员注销",
        "user.password_reset_admin": "重置密码",
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 6) {
                        Text("运营数据")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PlatformStyle.textSecondary)
                        if isLoading {
                            ProgressView().padding(.vertical, 16)
                        } else {
                            Text("\(appUserTotal)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(PlatformStyle.textPrimary)
                                .contentTransition(.numericText())
                            Text("App 用户")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PlatformStyle.textSecondary)
                        }
                    }
                    .padding(.horizontal, 4)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        statCard(title: "正常账本", value: "\(activeLedgerTotal)", tint: PlatformStyle.accentGreen.opacity(0.12), accent: PlatformStyle.accentGreen)
                        statCard(title: "归档账本", value: "\(archivedLedgerTotal)", tint: PlatformStyle.cardMuted, accent: PlatformStyle.textSecondary)
                        statCard(title: "悬空归档", value: "\(orphanLedgerTotal)", tint: PlatformStyle.accentOrange.opacity(0.12), accent: PlatformStyle.accentOrange)
                        statCard(title: "今日操作", value: "\(todayAuditTotal)", tint: PlatformStyle.accentPurple.opacity(0.12), accent: PlatformStyle.accentPurple)
                    }

                    // 审计日志（首页主内容）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("审计日志")
                                .font(.system(size: 17, weight: .bold))
                            Spacer()
                            NavigationLink {
                                PlatformAuditView()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("筛选 · 按日")
                                        .font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(PlatformStyle.accentPurple)
                            }
                        }

                        if !todayTopActions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(todayTopActions.prefix(4).enumerated()), id: \.offset) { _, row in
                                        HStack(spacing: 6) {
                                            Text(Self.actionLabels[row.0] ?? row.0)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("\(row.1)")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(PlatformStyle.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(PlatformStyle.cardMuted, in: Capsule())
                                    }
                                }
                            }
                        }

                        if isLoading && auditEvents.isEmpty {
                            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                        } else if auditEvents.isEmpty {
                            Text("今日暂无审计事件")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PlatformStyle.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(auditEvents.prefix(30)) { e in
                                    auditRow(e)
                                }
                            }
                        }

                        if auditEvents.count >= 30 || todayAuditTotal > auditEvents.count {
                            NavigationLink {
                                PlatformAuditView()
                            } label: {
                                Text("查看全部审计")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(PlatformStyle.blackCTA, in: Capsule())
                            }
                            .buttonStyle(PlatformPressStyle())
                            .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("铭牌")
                            .font(.system(size: 15, weight: .bold))
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(badgeCatalogCount)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text("铭牌类型")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PlatformStyle.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(unassignedBadgeUsers)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text("未佩戴用户")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PlatformStyle.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .platformSoftCard()

                    Text("下拉刷新 · 北京时间当日审计")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PlatformStyle.textTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(PlatformStyle.canvas)
            .navigationBarHidden(true)
            .task { await loadStats() }
            .refreshable { await loadStats() }
        }
    }

    private func auditRow(_ e: AuditEventItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.actionLabels[e.action] ?? e.action)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PlatformStyle.textPrimary)
                Spacer()
                Text(auditTimeLabel(e.createdAt))
                    .font(.caption)
                    .foregroundStyle(PlatformStyle.textTertiary)
            }
            Text(e.actorLabel ?? "—")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PlatformStyle.textSecondary)
            if let s = e.summary, !s.isEmpty {
                Text(s)
                    .font(.system(size: 12))
                    .foregroundStyle(PlatformStyle.textTertiary)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                miniChip(e.source ?? "api", color: PlatformStyle.accentPurple)
                if let ip = e.ip {
                    Text(ip)
                        .font(.caption2)
                        .foregroundStyle(PlatformStyle.textTertiary)
                }
            }
        }
        .platformCard(padding: 14)
    }

    private func auditTimeLabel(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                selectedTab = 4 // 我的
            } label: {
                HStack(spacing: 12) {
                    RemoteAvatarView(
                        avatarUrl: auth.user?.avatarUrl,
                        localImage: auth.avatarImage,
                        fallbackText: auth.user?.resolvedDisplayName ?? "运",
                        size: 40,
                        fallbackBackground: PlatformStyle.accentPink,
                        fallbackForeground: .white
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.user?.resolvedDisplayName ?? "平台账号")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PlatformStyle.textPrimary)
                        Text("平台运营")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PlatformStyle.accentPurple)
                    }
                }
            }
            .buttonStyle(PlatformPressStyle())
            Spacer()
            Button {
                Task { await loadStats() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PlatformStyle.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(PlatformStyle.cardMuted, in: Circle())
            }
            .buttonStyle(PlatformPressStyle())
        }
    }

    private func statCard(title: String, value: String, tint: Color, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(PlatformStyle.textPrimary)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(tint, in: RoundedRectangle(cornerRadius: PlatformStyle.cardRadius, style: .continuous))
    }

    private func shanghaiDayString() -> String {
        let dayFmt = DateFormatter()
        dayFmt.calendar = Calendar(identifier: .gregorian)
        dayFmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        dayFmt.dateFormat = "yyyy-MM-dd"
        return dayFmt.string(from: Date())
    }

    private func loadStats() async {
        isLoading = true
        let dayStr = shanghaiDayString()

        // Wave 1: parallel totals only (limit=1). Orphan uses dedicated filter (not 200-row scan).
        async let userN = fetchUserTotal()
        async let activeN = fetchLedgerTotal(status: "active")
        async let archivedN = fetchLedgerTotal(status: "archived")
        async let orphanN = fetchLedgerTotal(status: "orphan")

        let (u, a, ar, o) = await (userN, activeN, archivedN, orphanN)
        appUserTotal = u
        activeLedgerTotal = a
        archivedLedgerTotal = ar
        orphanLedgerTotal = o
        isLoading = false // paint stats ASAP

        // Wave 2: audit + badges in parallel
        async let auditPack = fetchHomeAudit(day: dayStr)
        async let badgePack = fetchBadgeStats()
        let (audit, badges) = await (auditPack, badgePack)

        todayAuditTotal = audit.total
        todayTopActions = audit.top
        auditEvents = audit.events
        badgeCatalogCount = badges.catalog
        unassignedBadgeUsers = badges.unassigned
    }

    // Helpers return Sendable Int/tuples so `async let` stays Swift-6 friendly
    // (avoid `async let x: SomeDecodable = …`).

    private func fetchUserTotal() async -> Int {
        let res: AdminUserListResponse? = try? await APIClient.shared.get(
            APIEndpoints.adminUsers(accountKind: "app", limit: 1)
        )
        return res?.total ?? 0
    }

    private func fetchLedgerTotal(status: String) async -> Int {
        let res: AdminLedgerListResponse? = try? await APIClient.shared.get(
            APIEndpoints.adminLedgers(status: status, limit: 1)
        )
        return res?.total ?? 0
    }

    private func fetchHomeAudit(day: String) async -> (total: Int, top: [(String, Int)], events: [AuditEventItem]) {
        var total = 0
        var top: [(String, Int)] = []
        var events: [AuditEventItem] = []

        if let sum: AuditSummaryResponse = try? await APIClient.shared.get(
            APIEndpoints.adminAuditSummary(day: day)
        ) {
            total = sum.total ?? 0
            top = (sum.byAction ?? [])
                .sorted { $0.count > $1.count }
                .prefix(5)
                .map { ($0.action, $0.count) }
        }

        do {
            let list: AuditEventListResponse = try await APIClient.shared.get(
                APIEndpoints.adminAuditEvents(day: day, limit: 15)
            )
            events = list.items
            if total == 0 { total = list.total }
        } catch {
            print("📡 Home audit list failed: \(error)")
        }
        return (total, top, events)
    }

    private func fetchBadgeStats() async -> (catalog: Int, unassigned: Int) {
        let b: AdminBadgeListResponse? = try? await APIClient.shared.get(APIEndpoints.adminBadges)
        guard let b else { return (badgeCatalogCount, unassignedBadgeUsers) }
        return (
            b.items.filter { $0.isActive != false }.count,
            b.unassignedCount ?? 0
        )
    }
}

// MARK: - Users

private struct PlatformUsersView: View {
    @State private var items: [AdminUserListItem] = []
    @State private var total = 0
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var selectedUser: AdminUserListItem?

    var body: some View {
        VStack(spacing: 0) {
            pageHeader(title: "用户", subtitle: total > 0 ? "共 \(total) 名 App 用户" : "App 用户目录")

            searchField

            Group {
                if isLoading && items.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorText, items.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(PlatformStyle.textTertiary)
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(PlatformStyle.textSecondary)
                            .multilineTextAlignment(.center)
                        blackCapsuleButton("重试") { Task { await load() } }
                    }
                    .padding(24)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { user in
                                Button {
                                    selectedUser = user
                                } label: {
                                    userRow(user)
                                }
                                .buttonStyle(PlatformPressStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await load() }
                }
            }
        }
        .background(PlatformStyle.canvas)
        .task { await load() }
        .sheet(item: $selectedUser) { user in
            PlatformUserDetailSheet(user: user) {
                Task { await load() }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .platformLightChrome()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PlatformStyle.textTertiary)
            TextField("搜邮箱 / 用户名", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await load() } }
            if !query.isEmpty {
                Button {
                    query = ""
                    Task { await load() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PlatformStyle.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PlatformStyle.cardMuted, in: Capsule(style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func userRow(_ user: AdminUserListItem) -> some View {
        HStack(spacing: 14) {
            RemoteAvatarView(
                avatarUrl: user.avatarUrl,
                fallbackText: user.listTitle,
                size: 48,
                fallbackBackground: avatarColor(for: user),
                fallbackForeground: .white
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.listTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PlatformStyle.textPrimary)
                        .lineLimit(1)
                    if user.status == "deactivated" {
                        miniChip("已注销", color: PlatformStyle.textSecondary)
                    }
                    UserBadgeChip(key: user.badge, label: user.badgeLabel, colorName: user.badgeColor, size: .compact)
                }
                Text("@\(user.username)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PlatformStyle.textSecondary)
                if user.status != "deactivated" {
                    Text(user.email)
                        .font(.system(size: 12))
                        .foregroundStyle(PlatformStyle.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(user.membershipCount ?? 0)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(PlatformStyle.textPrimary)
                Text("账本")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PlatformStyle.textTertiary)
            }
        }
        .platformCard(padding: 14)
    }

    private func avatarColor(for user: AdminUserListItem) -> Color {
        if user.status == "deactivated" { return PlatformStyle.textTertiary }
        let colors: [Color] = [
            PlatformStyle.accentPink,
            PlatformStyle.accentPurple,
            PlatformStyle.accentBlue,
            PlatformStyle.accentGreen,
        ]
        let idx = abs(user.username.hashValue) % colors.count
        return colors[idx]
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let res: AdminUserListResponse = try await APIClient.shared.get(
                APIEndpoints.adminUsers(
                    q: query.isEmpty ? nil : query,
                    accountKind: "app",
                    limit: 200
                )
            )
            items = res.items
            total = res.total
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - User detail sheet

private struct PlatformUserDetailSheet: View {
    let user: AdminUserListItem
    var onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isDeactivating = false
    @State private var message: String?
    @State private var showDeactivateConfirm = false
    @State private var transferSummary: [String] = []
    @State private var badges: [AdminBadgeItem] = []
    @State private var selectedBadgeKey: String?
    @State private var isResetting = false
    @State private var newPassword: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RemoteAvatarView(
                        avatarUrl: user.avatarUrl,
                        fallbackText: user.listTitle,
                        size: 80,
                        fallbackBackground: PlatformStyle.accentPink,
                        fallbackForeground: .white
                    )
                    .padding(.top, 8)

                    HStack(spacing: 8) {
                        Text(user.listTitle)
                            .font(.system(size: 22, weight: .bold))
                        UserBadgeChip(key: user.badge, label: user.badgeLabel, colorName: user.badgeColor, size: .regular)
                    }
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PlatformStyle.textSecondary)

                    HStack(spacing: 8) {
                        chip("UID", value: String(user.id.prefix(8)))
                        if user.status != "deactivated" {
                            chip("邮箱", value: user.email)
                        }
                    }

                    HStack(spacing: 12) {
                        statCard("所属", "\(user.membershipCount ?? 0)")
                        statCard("拥有", "\(user.ownedLedgerCount ?? 0)")
                        statCard("账单", "\(user.expenseCreatedCount ?? 0)")
                    }

                    VStack(spacing: 0) {
                        infoRow("类型", user.accountKind == "platform" ? "平台账号" : "普通用户")
                        Divider().opacity(0.5)
                        infoRow("状态", user.status == "deactivated" ? "已注销" : "正常")
                        if let badge = user.badgeLabel {
                            Divider().opacity(0.5)
                            infoRow("铭牌", badge)
                        }
                    }
                    .platformCard(padding: 4)

                    if !transferSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("注销结果")
                                .font(.system(size: 14, weight: .semibold))
                            ForEach(transferSummary, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 13))
                                    .foregroundStyle(PlatformStyle.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .platformSoftCard()
                    }

                    if user.status != "deactivated" {
                        // Badge picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("铭牌")
                                .font(.system(size: 14, weight: .semibold))
                            if badges.isEmpty {
                                Text("加载铭牌…")
                                    .font(.caption)
                                    .foregroundStyle(PlatformStyle.textTertiary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        badgePickChip(nil, label: "无")
                                        ForEach(badges) { b in
                                            badgePickChip(b.key, label: b.label)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .platformSoftCard()

                        blackCapsuleButton(isResetting ? "重置中…" : "重置密码") {
                            Task { await resetPassword() }
                        }
                        .disabled(isResetting)

                        if let newPassword {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("新密码（请截图或复制发给用户）")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PlatformStyle.textSecondary)
                                Text(newPassword)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                Button("复制密码") {
                                    UIPasteboard.general.string = newPassword
                                    message = "已复制"
                                }
                                .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .platformSoftCard()
                        }

                        if user.accountKind != "platform" {
                            blackCapsuleButton(isDeactivating ? "处理中…" : "注销此账号", destructive: true) {
                                showDeactivateConfirm = true
                            }
                            .disabled(isDeactivating)
                            Text("软注销：历史账单保留；拥有的账本将移交或归档。")
                                .font(.system(size: 12))
                                .foregroundStyle(PlatformStyle.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(20)
            }
            .background(PlatformStyle.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(PlatformStyle.textPrimary)
                }
            }
            .task { await loadBadges() }
            .alert("注销此账号？", isPresented: $showDeactivateConfirm) {
                Button("取消", role: .cancel) {}
                Button("确认注销", role: .destructive) {
                    Task { await deactivate() }
                }
            } message: {
                Text("对方将无法登录。Owner 账本自动移交或归档。")
            }
            .alert("提示", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func badgePickChip(_ key: String?, label: String) -> some View {
        let selected = (selectedBadgeKey ?? user.badge) == key
            || (key == nil && (selectedBadgeKey ?? user.badge) == nil)
        return Button {
            Task { await setBadge(key) }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : PlatformStyle.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? PlatformStyle.blackCTA : PlatformStyle.card, in: Capsule())
                .overlay(Capsule().stroke(PlatformStyle.hairline, lineWidth: 1))
        }
        .buttonStyle(PlatformPressStyle())
    }

    private func loadBadges() async {
        selectedBadgeKey = user.badge
        do {
            let res: AdminBadgeListResponse = try await APIClient.shared.get(APIEndpoints.adminBadges)
            badges = res.items.filter { $0.isActive != false }
        } catch {
            // non-blocking
        }
    }

    private func setBadge(_ key: String?) async {
        do {
            let _: UserResponse = try await APIClient.shared.patch(
                APIEndpoints.adminSetBadge(id: user.id),
                body: AdminSetBadgeBody(badge: key)
            )
            selectedBadgeKey = key
            message = key == nil ? "已清除铭牌" : "铭牌已更新"
            onChanged()
        } catch {
            message = error.localizedDescription
        }
    }

    private func resetPassword() async {
        isResetting = true
        defer { isResetting = false }
        let pwd = Self.randomPassword()
        do {
            let _: AdminResetPasswordResponse = try await APIClient.shared.post(
                APIEndpoints.adminResetPassword(id: user.id),
                body: AdminResetPasswordBody(newPassword: pwd)
            )
            newPassword = pwd
            message = "密码已重置"
        } catch {
            message = error.localizedDescription
        }
    }

    private static func randomPassword(length: Int = 10) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private func chip(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(PlatformStyle.textTertiary)
            Text(value)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PlatformStyle.cardMuted, in: Capsule())
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PlatformStyle.textPrimary)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PlatformStyle.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .platformSoftCard(padding: 14)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(PlatformStyle.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(PlatformStyle.textPrimary)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func deactivate() async {
        isDeactivating = true
        defer { isDeactivating = false }
        do {
            let res: DeactivateAccountResponse = try await APIClient.shared.post(
                APIEndpoints.adminDeactivateUser(id: user.id),
                body: DeactivateAccountRequest(ownerTransfers: [], confirm: true)
            )
            transferSummary = res.transfers.map { row in
                if row.action == "transfer", let o = row.newOwner {
                    return "「\(row.ledgerName)」→ \(o.displayName)"
                }
                if row.action == "archive" {
                    return "「\(row.ledgerName)」已归档"
                }
                return "「\(row.ledgerName)」\(row.action)"
            }
            message = transferSummary.isEmpty ? "已注销" : "已注销，请查看移交/归档结果"
            onChanged()
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - Ledgers

private struct PlatformLedgersView: View {
    @State private var items: [AdminLedgerListItem] = []
    @State private var total = 0
    @State private var query = ""
    @State private var statusFilter: String? = nil
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var selectedLedger: AdminLedgerListItem?

    // Status filters only; 悬空 is a tag on archived rows (not a separate filter).
    private let filters: [(String?, String)] = [
        (nil, "全部"),
        ("active", "正常"),
        ("archived", "归档"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            pageHeader(title: "账本", subtitle: total > 0 ? "共 \(total) 本" : "全局账本")

            // Capsule chips (not system segmented in a List)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.1) { value, title in
                        let selected = statusFilter == value
                        Button {
                            statusFilter = value
                            Task { await load() }
                        } label: {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? .white : PlatformStyle.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selected ? PlatformStyle.blackCTA : PlatformStyle.cardMuted,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(PlatformPressStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 10)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PlatformStyle.textTertiary)
                TextField("搜账本名", text: $query)
                    .submitLabel(.search)
                    .onSubmit { Task { await load() } }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PlatformStyle.cardMuted, in: Capsule())
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Group {
                if isLoading && items.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorText, items.isEmpty {
                    Spacer()
                    Text(errorText).foregroundStyle(PlatformStyle.textSecondary)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { ledger in
                                Button {
                                    selectedLedger = ledger
                                } label: {
                                    ledgerCard(ledger)
                                }
                                .buttonStyle(PlatformPressStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await load() }
                }
            }
        }
        .background(PlatformStyle.canvas)
        .task { await load() }
        .sheet(item: $selectedLedger) { ledger in
            PlatformLedgerDetailSheet(ledgerId: ledger.id, ledgerName: ledger.name)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .platformLightChrome()
        }
    }

    private func ledgerCard(_ ledger: AdminLedgerListItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ledger.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(PlatformStyle.textPrimary)
                    Text(ledger.ownerLabel ?? "—")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PlatformStyle.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    if ledger.status == "archived" {
                        miniChip("归档", color: PlatformStyle.textSecondary)
                    } else {
                        miniChip("正常", color: PlatformStyle.accentGreen)
                    }
                    if ledger.isOrphan == true {
                        miniChip("悬空", color: PlatformStyle.accentOrange)
                    }
                }
            }

            HStack(spacing: 16) {
                metric(icon: "person.2", text: "\(ledger.memberCount ?? 0)")
                metric(icon: "list.bullet", text: "\(ledger.expenseCount ?? 0)")
                Spacer()
                if let spend = ledger.totalSpend {
                    Text(String(format: "¥%.2f", spend))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(PlatformStyle.textPrimary)
                }
            }
        }
        .platformCard(padding: 16)
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(PlatformStyle.textTertiary)
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let res: AdminLedgerListResponse = try await APIClient.shared.get(
                APIEndpoints.adminLedgers(
                    q: query.isEmpty ? nil : query,
                    status: statusFilter,
                    limit: 200
                )
            )
            items = res.items
            total = res.total
        } catch {
            errorText = error.localizedDescription
        }
    }
}



// MARK: - Shared chrome

func pageHeader(title: String, subtitle: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(PlatformStyle.textPrimary)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PlatformStyle.textSecondary)
        }
        Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 12)
}

func miniChip(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
}

@ViewBuilder
func blackCapsuleButton(
    _ title: String,
    destructive: Bool = false,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                destructive ? Color(red: 0.85, green: 0.20, blue: 0.25) : PlatformStyle.blackCTA,
                in: Capsule(style: .continuous)
            )
    }
    .buttonStyle(PlatformPressStyle())
}
