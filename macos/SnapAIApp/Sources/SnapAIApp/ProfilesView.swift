import SwiftUI

struct ProfilesView: View {
    @ObservedObject var model: AppModel
    @State private var isCreatingProfile = false
    @State private var profileName = ""
    @State private var profileToDelete: StoredProfile?
    @State private var profileToEdit: StoredProfile?
    @State private var selectedFilter = "All"

    private let filters = ["All", "3D Icons", "Character Art", "UI Design", "Portrait"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                PageHeader(
                    eyebrow: "PRESET LIBRARY",
                    title: "Creative Workflow Profiles",
                    subtitle: "Save your favorite prompts, models, and parameters as instant one-click presets."
                )

                Spacer()

                Button {
                    profileName = ""
                    isCreatingProfile = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)

            if !model.profiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { category in
                            PillTag(category, isSelected: selectedFilter == category) {
                                selectedFilter = category
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                }
            }

            if model.profiles.isEmpty {
                EmptySectionView(
                    section: .profiles,
                    description: "Save custom prompts, models, styles, and quality choices as one-click workflow presets.",
                    actionTitle: "Create Preset Profile",
                    action: {
                        profileName = ""
                        isCreatingProfile = true
                    }
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                        ForEach(model.profiles) { profile in
                            profileCard(profile)
                        }
                    }
                    .padding(28)
                }
                .overlay(alignment: .top) {
                    ScrollEdgeFade(edge: .top)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Profiles")
        .sheet(isPresented: $isCreatingProfile) {
            NewProfileSheet(
                name: $profileName,
                onCancel: { isCreatingProfile = false },
                onSave: {
                    model.createProfile(named: profileName)
                    isCreatingProfile = false
                }
            )
        }
        .sheet(item: $profileToEdit) { profile in
            EditProfileSheet(
                profile: profile,
                onCancel: { profileToEdit = nil },
                onSave: { name, prompt in
                    model.updateProfile(profile, name: name, prompt: prompt)
                    profileToEdit = nil
                }
            )
        }
        .confirmationDialog(
            "Delete this profile?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) {
                if let profileToDelete {
                    model.deleteProfile(profileToDelete)
                }
                profileToDelete = nil
            }
        } message: {
            Text("The selected profile will be removed. Generated files and history will remain.")
        }
    }

    private func profileCard(_ profile: StoredProfile) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "wand.and.rays")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .accessibilityAddTraits(.isHeader)

                        Text(profile.draft.style.isEmpty ? profile.draft.model : profile.draft.style)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                }

                Text(profile.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                if let prompt = profile.prompt, !prompt.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Prompt", systemImage: "text.quote")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)

                        Text(prompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack {
                    Button {
                        model.activateProfile(profile)
                    } label: {
                        Label("Reuse", systemImage: "arrow.clockwise.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Reuse \(profile.name) profile")
                    .accessibilityHint("Applies this profile's saved settings")

                    Spacer()
                    Menu {
                        Button("Edit Profile", systemImage: "pencil") {
                            profileToEdit = profile
                        }
                        Button("Duplicate Profile", systemImage: "plus.square.on.square") {
                            model.duplicateProfile(profile)
                        }
                        Divider()
                        Button("Delete Profile", systemImage: "trash", role: .destructive) {
                            profileToDelete = profile
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More actions for \(profile.name)")
                }
            }
        }
    }
}

private struct EditProfileSheet: View {
    let profile: StoredProfile
    let onCancel: () -> Void
    let onSave: (String, String) -> Void
    @State private var name: String
    @State private var prompt: String

    init(profile: StoredProfile, onCancel: @escaping () -> Void, onSave: @escaping (String, String) -> Void) {
        self.profile = profile
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _prompt = State(initialValue: profile.prompt ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit profile")
                .font(.title2.weight(.semibold))
                .tracking(-0.015)
            Text("Profiles keep a reusable prompt and generation setup together.")
                .foregroundStyle(.secondary)
            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Optional prompt template", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    onSave(name, prompt)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

private struct NewProfileSheet: View {
    @Binding var name: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Profile")
                .font(.title2.weight(.semibold))
                .tracking(-0.015)
            Text("Save the current prompt and generation choices for reuse.")
                .foregroundStyle(.secondary)
            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSave)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
