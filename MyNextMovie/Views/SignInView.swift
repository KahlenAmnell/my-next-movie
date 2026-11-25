import SwiftUI

struct SignInView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        VStack(spacing: spacingExtraLarge) {
            header
            fields
            buttons
            status
        }
        .padding(spacingExtraLarge)
        .frame(maxHeight: .infinity)
        #if DEBUG
            .onAppear {
                viewModel.email = testAccountEmail
                viewModel.password = testAccountPassword
            }
        #endif
    }

    private var header: some View {
        VStack(spacing: spacingSmall) {
            Image(systemName: symbolNameMovies)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("My Next Movie")
                .font(.largeTitle.bold())
            Text("Sign in to keep your Watch Later list on every device you use.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var fields: some View {
        VStack(spacing: spacingMedium) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit { Task { await viewModel.signIn() } }
        }
    }

    private var buttons: some View {
        HStack(spacing: spacingMedium) {
            Button("Sign In") { Task { await viewModel.signIn() } }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSignIn)
            Button("Create Account") { Task { await viewModel.signUp() } }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canSignUp)
        }
    }

    @ViewBuilder
    private var status: some View {
        if viewModel.state == .loading {
            ProgressView()
        } else if viewModel.state == .failed {
            Text(viewModel.errorMessage)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else if viewModel.isWaitingForEmailConfirmation {
            Text("Check your email and click the link to confirm your account.")
                .multilineTextAlignment(.center)
        } else {
            Text("A new password needs at least \(minimumPasswordLength) characters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SignInView(viewModel: previewAccountViewModel(signedInEmail: ""))
}
