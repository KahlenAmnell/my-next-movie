import SwiftUI

struct AccountView: View {
    let viewModel: AccountViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Signed in as") {
                    Text(viewModel.signedInEmail)
                }
                Section("Saved movies") {
                    syncStatus
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await viewModel.signOut() }
                    }
                } footer: {
                    Text("Your saved movies stay on your account and disappear from this device.")
                }
            }
            .navigationTitle("Account")
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        switch viewModel.syncState {
        case .idle, .loading:
            Label("Syncing with your account", systemImage: symbolNameSyncing)
        case .loaded:
            Label("In sync with your account", systemImage: symbolNameSynced)
        case .failed:
            Text(viewModel.syncErrorMessage)
                .foregroundStyle(.red)
            Button("Try again") {
                Task { await viewModel.syncSavedMovies() }
            }
        }
    }
}

#Preview {
    AccountView(viewModel: previewAccountViewModel(signedInEmail: testAccountEmail))
}
