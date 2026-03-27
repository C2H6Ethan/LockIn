import SwiftUI

struct BlockCustomURLsView: View {

    var viewModel: SettingsViewModel

    @State private var showingAddAlert = false
    @State private var newDomain = ""

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            List {
                Section {
                    // empty — header carries the subtitle
                } header: {
                    Text("Unlike the app picker — which only shows sites from your Safari history — you can block any domain here. Up to 50 domains.")
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .textCase(nil)
                        .padding(.bottom, DesignSystem.Spacing.sm)
                }

                Section {
                    if viewModel.customDomains.isEmpty {
                        Text("No domains added")
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .listRowBackground(DesignSystem.Colors.background)
                    } else {
                        ForEach(viewModel.customDomains, id: \.self) { domain in
                            Text(domain)
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                                .listRowBackground(DesignSystem.Colors.background)
                                .swipeActions(edge: .trailing) {
                                    if !viewModel.isLocked {
                                        Button(role: .destructive) {
                                            viewModel.removeCustomDomain(domain)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Custom Domains")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if viewModel.customDomains.count < 50 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
        }
        .alert("Add Domain", isPresented: $showingAddAlert) {
            TextField("reddit.com", text: $newDomain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Add") {
                viewModel.addCustomDomain(newDomain)
                newDomain = ""
            }
            .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newDomain = ""
            }
        } message: {
            Text("Enter a domain to block (e.g. reddit.com)")
        }
    }
}
