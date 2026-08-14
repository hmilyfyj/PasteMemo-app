import SwiftUI

/// 接力窗口内嵌的"删除回流"提示 — 显示在 Hero 卡片上方的 overlay，6 秒后自动消失或
/// 用户点撤销后消失。和 GlobalToast 不同：带一个可点的"撤销"按钮。
struct RelayUndoToast: View {
    let message: String
    let actionTitle: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green.opacity(0.85))
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button(action: onAction) {
                Text(actionTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        )
        .padding(8)
    }
}
