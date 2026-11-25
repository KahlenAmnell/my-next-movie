import Foundation
import Observation

@Observable
final class AccountViewModel {
    var email = ""
    var password = ""

    private(set) var signedInEmail: String
    private(set) var state = LoadState.idle
    private(set) var errorMessage = ""
    private(set) var isWaitingForEmailConfirmation = false
    private(set) var syncState = LoadState.idle
    private(set) var syncErrorMessage = ""

    private let account: AccountService
    private let runSync: () async throws -> Void
    private let clearSavedMovies: @MainActor () -> Void
    private var isSyncing = false
    private var syncWasRequested = false

    init(
        account: AccountService,
        syncSavedMovies: @escaping () async throws -> Void,
        clearSavedMovies: @escaping @MainActor () -> Void
    ) {
        self.account = account
        self.runSync = syncSavedMovies
        self.clearSavedMovies = clearSavedMovies
        self.signedInEmail = account.signedInEmail()
    }

    var isSignedIn: Bool {
        return !signedInEmail.isEmpty
    }

    var canSignIn: Bool {
        return !trimmedEmail.isEmpty && !password.isEmpty && state != .loading
    }

    var canSignUp: Bool {
        return canSignIn && password.count >= minimumPasswordLength
    }

    func signIn() async {
        await submit(account.signIn)
    }

    func signUp() async {
        await submit(account.signUp)
    }

    func syncSavedMovies() async {
        if !isSignedIn {
            return
        }
        if isSyncing {
            syncWasRequested = true
            return
        }
        isSyncing = true
        repeat {
            syncWasRequested = false
            await syncOnce()
        } while syncWasRequested
        isSyncing = false
    }

    func signOut() async {
        await syncSavedMovies()
        do {
            try await account.signOut()
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
            return
        }
        signedInEmail = ""
        syncState = .idle
        syncErrorMessage = ""
        clearSavedMovies()
    }

    private var trimmedEmail: String {
        return email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit(_ request: AccountRequest) async {
        state = .loading
        errorMessage = ""
        isWaitingForEmailConfirmation = false
        do {
            let newEmail = try await request(trimmedEmail, password)
            state = .loaded
            if newEmail.isEmpty {
                isWaitingForEmailConfirmation = true
                return
            }
            signedInEmail = newEmail
            password = ""
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
            return
        }
        await syncSavedMovies()
    }

    private func syncOnce() async {
        syncState = .loading
        do {
            try await runSync()
            syncState = .loaded
        } catch {
            syncErrorMessage = error.localizedDescription
            syncState = .failed
        }
    }
}
