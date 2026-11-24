import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

@MainActor
func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Schema(storedModelTypes), configurations: [configuration])
}

private func makeFullMovie() -> Movie {
    return Movie(
        id: 603,
        title: "The Matrix",
        overview: "A hacker learns the truth.",
        releaseDate: "1999-03-31",
        posterPath: "/matrix.jpg",
        voteAverage: 8.2,
        genreIds: [28, 878]
    )
}

private let savedAtTime = Date(timeIntervalSince1970: 0)

@MainActor
struct SavedMovieTests {
    @Test func toggleSavesThenRemoves() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = makeFullMovie()

        toggleSavedMovie(context, movie, now: savedAtTime)
        #expect(isMovieSaved(context, movieId: movie.id))

        toggleSavedMovie(context, movie, now: savedAtTime)
        #expect(!isMovieSaved(context, movieId: movie.id))
    }

    @Test func savedCopyKeepsEveryField() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = makeFullMovie()

        toggleSavedMovie(context, movie, now: savedAtTime)

        let savedCopies = fetchSavedMovies(context, movieId: movie.id)
        #expect(moviesFromSaved(savedCopies) == [movie])
    }
}
