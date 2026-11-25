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

/// A moment `minutes` after the start of the test clock.
private func minute(_ minutes: Int) -> Date {
    return savedAtTime.addingTimeInterval(60 * Double(minutes))
}

/// Search texts in the order the Search screen would show them.
@MainActor
private func recentQueries(_ context: ModelContext) -> [String] {
    return recentSearches(context).map(\.query)
}

@MainActor
struct SearchHistoryTests {
    @Test func newestSearchComesFirst() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))

        #expect(recentQueries(context) == ["alien", "matrix"])
    }

    @Test func repeatedSearchMovesToTop() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))
        recordSearch(context, query: "matrix", now: minute(3))

        #expect(recentQueries(context) == ["matrix", "alien"])
    }

    @Test func emptyAndSpacesAreNotRecorded() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "", now: minute(1))
        recordSearch(context, query: "   ", now: minute(2))
        recordSearch(context, query: "  dune  ", now: minute(3))

        #expect(recentQueries(context) == ["dune"])
    }

    @Test func keepsOnlyRecentSearches() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let searchCount = maxSearchHistoryCount + 3

        for number in 0..<searchCount {
            recordSearch(context, query: "movie \(number)", now: minute(number))
        }

        let storedCount = try context.fetchCount(FetchDescriptor<SearchHistoryEntry>())
        #expect(storedCount == maxSearchHistoryCount)
        #expect(recentQueries(context).first == "movie \(searchCount - 1)")
    }

    @Test func clearRemovesEverything() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))

        clearSearchHistory(context)

        #expect(recentQueries(context).isEmpty)
    }
}
