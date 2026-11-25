import Foundation
import Supabase

private let savedMoviesTable = "saved_movies"
private let columnId = "id"
private let columnSavedAt = "saved_at"
private let savedMoviesConflictKey = "user_id,id"

let minimumPasswordLength = 6
let testAccountEmail = "test@test.test"
let testAccountPassword = "test"

nonisolated struct SupabaseError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

nonisolated struct CloudSavedMovie: Codable, Equatable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String
    let posterPath: String?
    let voteAverage: Double
    let genreIds: [Int]
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
        case savedAt = "saved_at"
    }
}

// MARK: - Client

private var supabaseClient: SupabaseClient?

private func requireSupabaseClient() throws -> SupabaseClient {
    if let supabaseClient {
        return supabaseClient
    }
    guard let url = URL(string: supabaseURL()), url.host != nil, !supabaseAnonKey().isEmpty
    else {
        throw SupabaseError(
            message: "Missing Supabase keys. Add them to Config/Secrets.xcconfig.")
    }
    let newClient = SupabaseClient(supabaseURL: url, supabaseKey: supabaseAnonKey())
    supabaseClient = newClient
    return newClient
}

// MARK: - Account

func supabaseSignedInEmail() -> String {
    let client = try? requireSupabaseClient()
    return client?.auth.currentUser?.email ?? ""
}

func signInToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let session = try await client.auth.signIn(email: email, password: password)
    return session.user.email ?? ""
}

func signUpToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let response = try await client.auth.signUp(email: email, password: password)
    guard let session = response.session else {
        return ""
    }
    return session.user.email ?? ""
}

func signOutOfSupabase() async throws {
    let client = try requireSupabaseClient()
    try? await client.auth.signOut()
}

let supabaseAccountService = AccountService(
    signedInEmail: supabaseSignedInEmail,
    signIn: signInToSupabase,
    signUp: signUpToSupabase,
    signOut: signOutOfSupabase
)

// MARK: - Saved movies

func fetchCloudSavedMovies() async throws -> [CloudSavedMovie] {
    let client = try requireSupabaseClient()
    let cloudMovies: [CloudSavedMovie] = try await client
        .from(savedMoviesTable)
        .select()
        .order(columnSavedAt, ascending: false)
        .execute()
        .value
    return cloudMovies
}

func uploadCloudSavedMovies(_ cloudMovies: [CloudSavedMovie]) async throws {
    if cloudMovies.isEmpty {
        return
    }
    let client = try requireSupabaseClient()
    try await client
        .from(savedMoviesTable)
        .upsert(
            cloudMovies,
            onConflict: savedMoviesConflictKey,
            returning: .minimal,
            ignoreDuplicates: true
        )
        .execute()
}

func removeCloudSavedMovie(movieId: Int) async throws {
    let client = try requireSupabaseClient()
    try await client
        .from(savedMoviesTable)
        .delete(returning: .minimal)
        .eq(columnId, value: movieId)
        .execute()
}

let supabaseSavedMoviesCloud = SavedMoviesCloud(
    fetchMovies: fetchCloudSavedMovies,
    uploadMovies: uploadCloudSavedMovies,
    removeMovie: { movieId in try await removeCloudSavedMovie(movieId: movieId) }
)
