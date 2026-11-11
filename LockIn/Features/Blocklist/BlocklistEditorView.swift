import FamilyControls
import LockInPlatform
import SwiftUI

/// Pick apps, categories and websites to shield, plus hand-typed websites.
struct BlocklistEditorView: View {
    @State var model: BlocklistEditorModel
    @State private var showsPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showsPicker = true
                    } label: {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Apps and categories")
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                            Text(model.pickedSummary)
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .listRowBackground(DesignSystem.Colors.background)

                Section {
                    HStack {
                        TextField("example.com", text: $model.domainInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .onSubmit(model.addDomain)
                        Button("Add", action: model.addDomain)
                            .disabled(model.domainInput.isEmpty)
                    }
                    if let message = model.lockMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.destructive)
                    }
                    if let error = model.domainError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    ForEach(model.blocklist.customDomains, id: \.self) { domain in
                        Text(domain)
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                            .deleteDisabled(model.isLocked)
                    }
                    .onDelete(perform: model.removeDomains)
                } header: {
                    Text("WEBSITES")
                        .font(.footnote.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                .listRowBackground(DesignSystem.Colors.background)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Blocklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if model.save() { dismiss() }
                    }
                }
            }
            .familyActivityPicker(isPresented: $showsPicker, selection: $model.blocklist.selection)
        }
        .tint(DesignSystem.Colors.accent)
        .presentationBackground(DesignSystem.Colors.background)
    }
}
