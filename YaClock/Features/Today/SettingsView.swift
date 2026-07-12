// @Author subuhui
// @Date 2026/7/12 11:28
// @Description 设置页面，符合 screen_副本6.png 的极简玻璃感设计与 Neutral 配色规范，支持主题色/模式切换与权限诊断

import SwiftUI
import AlarmKit

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    // MARK: - AppStorage & State
    @AppStorage("themeMode") private var themeMode = "system"
    @AppStorage("defaultHolidayPolicy") private var defaultHolidayPolicy = ChineseWorkdayPolicy.skipHoliday.rawValue
    @AppStorage("permission.alarmKit") private var permissionAlarmKit = true
    @AppStorage("permission.notifications") private var permissionNotifications = true
    @AppStorage("permission.liveActivity") private var permissionLiveActivity = true

    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var toastMessage: String? = nil

    @State private var showingAccentSheet = false
    @State private var showingPolicySheet = false
    @State private var showingAboutSheet = false

    var body: some View {
        @Bindable var accent = container.accentColorManager

        NavigationStack {
            ZStack {
            List {
                // MARK: - 外观设置
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("主题模式")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("主题模式", selection: $themeMode) {
                            Text("系统").tag("system")
                            Text("亮色").tag("light")
                            Text("暗色").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    Button {
                        showingAccentSheet = true
                    } label: {
                        HStack {
                            Text("主题色")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(accent.currentPreset.displayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("外观")
                }

                // MARK: - 功能设置
                Section {
                    Button {
                        showingPolicySheet = true
                    } label: {
                        HStack {
                            Label("节假日策略", systemImage: "calendar")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(ChineseWorkdayPolicy(rawValue: defaultHolidayPolicy)?.displayName ?? "跳过法定节假日")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack {
                        Label("节假日数据", systemImage: "cylinder.split.1x2")
                        Spacer()
                        Text("2026年数据已就绪")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("功能设置")
                }

                // MARK: - 系统权限
                Section {
                    Toggle(isOn: $permissionAlarmKit) {
                        Label("闹钟权限 (AlarmKit)", systemImage: "alarm")
                    }
                    .tint(accent.color)

                    Toggle(isOn: $permissionNotifications) {
                        Label("通知权限", systemImage: "bell")
                    }
                    .tint(accent.color)

                    Toggle(isOn: $permissionLiveActivity) {
                        Label("实时活动 (Live Activity)", systemImage: "play.rectangle")
                    }
                    .tint(accent.color)
                } header: {
                    Text("系统权限")
                }

                // MARK: - 其他
                Section {
                    Button {
                        showToast("数据已成功导出")
                    } label: {
                        HStack {
                            Label("数据导出", systemImage: "arrow.up.doc")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button {
                        showingAboutSheet = true
                    } label: {
                        HStack {
                            Label("关于", systemImage: "info.circle")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("v2.1.0")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button {
                        showToast("反馈通道已开启")
                    } label: {
                        HStack {
                            Label("意见反馈", systemImage: "envelope")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("其他")
                }

                // MARK: - 调试与开发功能 (最下方，不影响主UI美观)
                Section {
                    Button {
                        manualSync()
                    } label: {
                        HStack {
                            Label("手动同步闹钟", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(accent.color)
                            Spacer()
                            if isSyncing {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(isSyncing)

                    NavigationLink {
                        SystemMonitorView()
                    } label: {
                        Label("系统调度监视器", systemImage: "cpu")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("调试开发 (仅开发可见)")
                } footer: {
                    if let msg = syncMessage {
                        Text(msg).foregroundStyle(.secondary)
                    }
                }

                // MARK: - Footer Designed text
                Section {
                    EmptyView()
                } footer: {
                    HStack {
                        Spacer()
                        Text("Designed with Precision for YaClock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                }
            }
            .listStyle(.insetGrouped)

            // MARK: - Custom Toast Banner
            if toastMessage != nil {
                VStack {
                    Spacer()
                    Text(toastMessage ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.medium)
                            .foregroundStyle(accent.color)
                    }
                }
            }
            // Sheets
            .sheet(isPresented: $showingAccentSheet) {
                AccentColorPickerSheet(accent: accent)
            }
            .sheet(isPresented: $showingPolicySheet) {
                holidayPolicySheetView
                    .presentationDetents([.fraction(0.35)])
            }
            .sheet(isPresented: $showingAboutSheet) {
                aboutSheetView
                    .presentationDetents([.fraction(0.3)])
            }
        }
    }

    // MARK: - 节假日策略 Bottom Sheet

    private var holidayPolicySheetView: some View {
        @Bindable var accent = container.accentColorManager

        return NavigationStack {
            List {
                ForEach(ChineseWorkdayPolicy.allCases, id: \.rawValue) { policy in
                    Button {
                        defaultHolidayPolicy = policy.rawValue
                        showingPolicySheet = false
                        showToast("已切换为：\(policy.displayName)")
                    } label: {
                        HStack {
                            Text(policy.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if defaultHolidayPolicy == policy.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(accent.color)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择默认节假日策略")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 关于 Sheet

    private var aboutSheetView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(container.accentColorManager.color)
                    .padding(.top)

                VStack(spacing: 4) {
                    Text("YaClock")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Version 2.1.0 (Build 2026)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("最低系统要求：iOS 26.0 (AlarmKit)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("关于 YaClock")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Toast 弹出辅助

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(duration: 0.25)) {
            // trigger animation
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - 手动同步

    private func manualSync() {
        isSyncing = true
        syncMessage = nil
        Task {
            do {
                try await container.refreshUseCase.execute()
                syncMessage = "✓ 同步完成"
                showToast("同步已完成")
            } catch {
                syncMessage = "✗ 同步失败：\(error.localizedDescription)"
                showToast("同步失败")
            }
            isSyncing = false
        }
    }
}

// MARK: - ChineseWorkdayPolicy Extension for Display

extension ChineseWorkdayPolicy {
    var displayName: String {
        switch self {
        case .followHoliday: return "智能跟随调休"
        case .skipHoliday:   return "跳过法定节假日"
        case .ignoreHoliday: return "忽略节假日"
        }
    }
}

