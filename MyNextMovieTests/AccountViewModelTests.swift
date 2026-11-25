import Testing

@testable import MyNextMovie

/// Pretends to be Supabase: remembers who is signed in and what was called.
@MainActor
private final class TestAccount {
    var signedInEmail = ""
    var isOffline = false
    var needsEmailConfirmation = false
    var failsToSync = false
    var syncCount = 0
    var clearCount = 0
    var lastRequestEmail = ""
    /// "sync", "signOut" and "clear" in the order they happened.
    var events: [String] = []

    func signIn(email: String, password: String) async throws -> String {
        if isOffline {
            throw NoConnection()
        }
        lastRequestEmail = email
        signedInEmail = email
        return email
    }

    func signUp(email: String, password: String) async throws -> String {
        if needsEmailConfirmation {
            return ""
        }
        return try await signIn(email: email, password: password)
    }

    func sync() async throws {
        syncCount += 1
        events.append("sync")
        if failsToSync {
            throw NoConnection()
        }
    }

    func signOut() async throws {
        events.append("signOut")
        signedInEmail = ""
    }

    func clear() {
        clearCount += 1
        events.append("clear")
    }
}

@MainActor
private func makeViewModel(_ account: TestAccount) -> AccountViewModel {
    let service = AccountService(
        signedInEmail: { account.signedInEmail },
        signIn: { email, password in try await account.signIn(email: email, password: password) },
        signUp: { email, password in try await account.signUp(email: email, password: password) },
        signOut: { try await account.signOut() }
    )
    return AccountViewModel(
        account: service,
        syncSavedMovies: { try await account.sync() },
        clearSavedMovies: { account.clear() }
    )
}

private let goodPassword = "secret"

@MainActor
struct AccountViewModelTests {
    @Test func startsSignedOut() {
        let viewModel = makeViewModel(TestAccount())

        #expect(!viewModel.isSignedIn)
        #expect(viewModel.signedInEmail.isEmpty)
    }

    @Test func newAccountNeedsLongEnoughPassword() {
        let viewModel = makeViewModel(TestAccount())
        viewModel.email = "a@b.c"

        viewModel.password = String(repeating: "x", count: minimumPasswordLength - 1)
        #expect(viewModel.canSignIn)
        #expect(!viewModel.canSignUp)

        viewModel.password = String(repeating: "x", count: minimumPasswordLength)
        #expect(viewModel.canSignUp)
    }

    @Test func signInTrimsEmailClearsPasswordAndSyncs() async {
        let account = TestAccount()
        let viewModel = makeViewModel(account)
        viewModel.email = "  a@b.c  "
        viewModel.password = goodPassword

        await viewModel.signIn()

        #expect(account.lastRequestEmail == "a@b.c")
        #expect(viewModel.signedInEmail == "a@b.c")
        #expect(viewModel.password.isEmpty)
        #expect(account.syncCount == 1)
    }

    @Test func showsErrorWhenSignInFails() async {
        let account = TestAccount()
        account.isOffline = true
        let viewModel = makeViewModel(account)
        viewModel.email = "a@b.c"
        viewModel.password = goodPassword

        await viewModel.signIn()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
        #expect(!viewModel.isSignedIn)
    }

    @Test func signUpSignsInWhenNoConfirmationIsNeeded() async {
        let viewModel = makeViewModel(TestAccount())
        viewModel.email = "new@b.c"
        viewModel.password = goodPassword

        await viewModel.signUp()

        #expect(viewModel.isSignedIn)
        #expect(!viewModel.isWaitingForEmailConfirmation)
    }

    @Test func signUpWaitsForEmailConfirmation() async {
        let account = TestAccount()
        account.needsEmailConfirmation = true
        let viewModel = makeViewModel(account)
        viewModel.email = "new@b.c"
        viewModel.password = goodPassword

        await viewModel.signUp()

        #expect(viewModel.isWaitingForEmailConfirmation)
        #expect(!viewModel.isSignedIn)
    }

    @Test func userFromLastTimeIsSignedInAtOnce() {
        let account = TestAccount()
        account.signedInEmail = "old@b.c"

        let viewModel = makeViewModel(account)

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == "old@b.c")
    }

    @Test func doesNotSyncWhenSignedOut() async {
        let account = TestAccount()
        let viewModel = makeViewModel(account)

        await viewModel.syncSavedMovies()

        #expect(account.syncCount == 0)
        #expect(viewModel.syncState == .idle)
    }

    @Test func showsErrorWhenSyncFails() async {
        let account = TestAccount()
        account.signedInEmail = "a@b.c"
        account.failsToSync = true
        let viewModel = makeViewModel(account)

        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .failed)
        #expect(viewModel.syncErrorMessage == "No connection")
    }

    @Test func syncWorksAgainAfterFailure() async {
        let account = TestAccount()
        account.signedInEmail = "a@b.c"
        account.failsToSync = true
        let viewModel = makeViewModel(account)
        await viewModel.syncSavedMovies()

        account.failsToSync = false
        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .loaded)
    }

    @Test func signOutSyncsThenClearsDevice() async {
        let account = TestAccount()
        account.signedInEmail = "a@b.c"
        let viewModel = makeViewModel(account)

        await viewModel.signOut()

        #expect(account.events == ["sync", "signOut", "clear"])
        #expect(!viewModel.isSignedIn)
        #expect(account.clearCount == 1)
    }
}
