// @Author subuhui
// @Date 2026/7/12 19:10
// @Description 提供全局主题色预设与自定义 HSL 配色选择的 Sheet 弹窗组件

import SwiftUI

/// 主题色选择器 Sheet
struct AccentColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var accent: AccentColorManager

    // 网格布局设定
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 预设网格
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(AccentPreset.allCases) { preset in
                            presetCell(preset)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // 自定义滑块
                    if accent.currentPreset == .custom {
                        VStack(spacing: 16) {
                            Divider()
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("微调色彩")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                VStack(spacing: 12) {
                                    // 色相
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("色相")
                                            Spacer()
                                            Text("\(Int(accent.customHue))°")
                                                .monospacedDigit()
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                        Slider(value: $accent.customHue, in: 0...360)
                                            .tint(accent.color)
                                    }

                                    // 饱和度
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("饱和度")
                                            Spacer()
                                            Text("\(Int(accent.customSaturation * 100))%")
                                                .monospacedDigit()
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                        Slider(value: $accent.customSaturation, in: 0...1)
                                            .tint(accent.color)
                                    }

                                    // 亮度
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("亮度")
                                            Spacer()
                                            Text("\(Int(accent.customLightness * 100))%")
                                                .monospacedDigit()
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                        Slider(value: $accent.customLightness, in: 0.2...0.8)
                                            .tint(accent.color)
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("选择主题色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(accent.color)
                }
            }
        }
    }

    // MARK: - 预设色块渲染

    private func presetCell(_ preset: AccentPreset) -> some View {
        let isSelected = accent.currentPreset == preset

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(presetColor(preset))
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

                if isSelected {
                    Circle()
                        .stroke(accent.color, lineWidth: 3)
                        .frame(width: 64, height: 64)

                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(checkmarkColor(preset))
                }
            }
            .frame(height: 68)

            Text(preset.displayName)
                .font(.footnote)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? accent.color.opacity(0.15) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.snappy(duration: 0.22)) {
                accent.select(preset)
            }
        }
    }

    // MARK: - 辅助预设颜色方法

    private func presetColor(_ preset: AccentPreset) -> Color {
        switch preset {
        case .auto:
            // 自动渐变
            return Color(hex: "2563EB")
        case .ocean:
            return Color(hex: "2563EB")
        case .forest:
            return Color(hex: "16A34A")
        case .sunset:
            return Color(hex: "EA580C")
        case .violet:
            return Color(hex: "7C3AED")
        case .rose:
            return Color(hex: "DB2777")
        case .mint:
            return Color(hex: "0F9D8A")
        case .slate:
            return Color(hex: "475569")
        case .midnight:
            return Color(hex: "334155")
        case .custom:
            return Color(hue: accent.customHue / 360.0, saturation: accent.customSaturation, brightness: accent.customLightness)
        }
    }

    private func checkmarkColor(_ preset: AccentPreset) -> Color {
        return .white // 统一使用白色以保持高对比度
    }
}
