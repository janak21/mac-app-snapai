import SwiftUI

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .tracking(-0.022)
                .lineSpacing(2)
                .lineLimit(2)
            Text(subtitle)
                .font(.title3)
                .tracking(-0.011)
                .foregroundStyle(.secondary)
                // NOTE: `.fixedSize(horizontal: false, vertical: true)` intentionally
                // omitted. When PageHeader sits in a plain VStack next to a vertically
                // greedy sibling (e.g. `.frame(maxHeight: .infinity)` or a ScrollView)
                // inside a NavigationSplitView detail, that modifier drives a width↔height
                // measurement feedback loop that inflates the split view to ~2x the
                // window and scrolls the sidebar content off-screen (blank sidebar).
                // The subtitle still wraps fully in a vertically-flexible VStack.
        }
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .tracking(-0.011)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

struct PillTag: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2.weight(.semibold))
                }
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.primary.opacity(0.06)),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(DeckTileButtonStyle())
        .animation(selectionAnimation, value: isSelected)
    }

    private var selectionAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.14)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

struct GlowButton: View {
    let title: String
    let icon: String
    let isGenerating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isGenerating ? "sparkles" : icon)
                    .font(.body.weight(.semibold))
                    .symbolEffect(.bounce, value: isGenerating)
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .foregroundStyle(.white)
            .shadow(color: Color.purple.opacity(0.35), radius: 8, x: 0, y: 4)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(DeckTileButtonStyle())
    }
}

struct StatusBadge: View {
    let title: String
    let icon: String
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isOnline ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
                .shadow(color: (isOnline ? Color.green : Color.orange).opacity(0.6), radius: 4)
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct EmptySectionView: View {
    let section: AppSection
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 68, height: 68)
                    Image(systemName: section.symbolName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                Text(section.title)
                    .font(.title2.weight(.bold))
                    .tracking(-0.015)
                Text(description)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    // See PageHeader: `.fixedSize(vertical: true)` next to a greedy
                    // sibling inside a NavigationSplitView detail loops the layout and
                    // collapses the sidebar. The `.frame(maxWidth: 400)` already bounds
                    // the width so the description wraps correctly without it.

                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text(actionTitle)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DeckTileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.985)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

struct ScrollEdgeFade: View {
    enum Edge {
        case top, bottom
    }

    let edge: Edge
    var color: Color = Color(nsColor: .windowBackgroundColor)
    var height: CGFloat = 14

    var body: some View {
        LinearGradient(
            colors: edge == .top
                ? [color, color.opacity(0)]
                : [color.opacity(0), color],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
    }
}
