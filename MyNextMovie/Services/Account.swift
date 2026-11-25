import Foundation

struct SavedMoviesCloud {
    var fetchMovies: () async throws -> [CloudSavedMovie]
    var uploadMovies: (_ cloudMovies: [CloudSavedMovie]) async throws -> Void
    var removeMovie: (_ movieId: Int) async throws -> Void
}

// TODO: Lab 5 - AccountRequest and AccountService (account step).
