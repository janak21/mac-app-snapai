import AppKit
import SwiftUI

enum ToastKind: Equatable {
    case success
    case error
    case warning
    case info

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: .green
        case .error: .red
        case .warning: .orange
        case .info: Color.accentColor
        }
    }

    var autoDismiss: Duration {
        switch self {
        case .success, .info: .milliseconds(3500)
        case .error, .warning: .milliseconds(5500)
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let kind: ToastKind
    let message: String
}

@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var active: Toast?

    private var dismissTask: Task<Void, Never>?

    func present(_ toast: Toast) {
        #if canImport(AppKit)
        NSSound(named: NSSound.Name("Glass"))?.play()
        #endif
        active = toast
        let duration = toast.kind.autoDismiss
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                active = nil
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        if active != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                active = nil
            }
        }
    }

    func success(_ message: String) {
        present(Toast(kind: .success, message: message))
    }

    func error(_ message: String) {
        present(Toast(kind: .error, message: message))
    }

    func warning(_ message: String) {
        present(Toast(kind: .warning, message: message))
    }

    func info(_ message: String) {
        present(Toast(kind: .info, message: message))
    }
}

struct ToastOverlay: View {
    @ObservedObject var center: ToastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if let toast = center.active {
                ToastCard(toast: toast, reduceMotion: reduceMotion) {
                    center.dismiss()
                }
                .padding(.top, 16)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                )
                .zIndex(1)
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.82),
            value: center.active
        )
        .zIndex(100)
    }
}

private struct ToastCard: View {
    let toast: Toast
    let reduceMotion: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.kind.symbol)
                .foregroundStyle(toast.kind.tint)
                .font(.title3)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320, alignment: .leading)
                .lineLimit(3)
        }
        .onTapGesture(perform: onDismiss)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        .help("Tap to dismiss")
        .accessibilityLabel(toast.message)
    }
}