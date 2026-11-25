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

    @Test func removingMovieTheAccountHasLeavesAMark() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = makeFullMovie()
        context.insert(SavedMovie(movie: movie, savedAt: savedAtTime, isInCloud: true))

        toggleSavedMovie(context, movie, now: savedAtTime)

        #expect(!isMovieSaved(context, movieId: movie.id))
        let marks = try context.fetch(FetchDescriptor<RemovedSavedMovie>())
        #expect(marks.map(\.movieId) == [movie.id])
    }

    @Test func removingMovieOnlyOnDeviceLeavesNoMark() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = makeFullMovie()

        toggleSavedMovie(context, movie, now: savedAtTime)
        toggleSavedMovie(context, movie, now: savedAtTime)

        #expect(try context.fetchCount(FetchDescriptor<RemovedSavedMovie>()) == 0)
    }

    @Test func clearRemovesMoviesAndMarks() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = makeFullMovie()
        context.insert(SavedMovie(movie: movie, savedAt: savedAtTime, isInCloud: false))
        context.insert(RemovedSavedMovie(movieId: 11))

        clearSavedMovies(context)

        #expect(try context.fetchCount(FetchDescriptor<SavedMovie>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RemovedSavedMovie>()) == 0)
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

private let cacheKey = "popular"
private let oldJSON = Data(#"{"results": []}"#.utf8)
private let newJSON = Data(#"{"results": [{"id": 1}]}"#.utf8)

private func fetchWithoutConnection() async throws -> Data {
    throw NoConnection()
}

@MainActor
struct ResponseCacheTests {
    @Test func missingKeyGivesEmptyData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        #expect(cachedResponseData(context, key: cacheKey) == Data())
    }

    @Test func storingAgainReplacesData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        storeCachedResponse(context, key: cacheKey, data: oldJSON, now: minute(1))
        storeCachedResponse(context, key: cacheKey, data: newJSON, now: minute(2))

        #expect(cachedResponseData(context, key: cacheKey) == newJSON)
        #expect(try context.fetchCount(FetchDescriptor<CachedResponse>()) == 1)
    }

    @Test func freshAnswerIsReturnedAndCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let answer = try await fetchWithCacheFallback(context, key: cacheKey) { newJSON }

        #expect(answer == newJSON)
        #expect(cachedResponseData(context, key: cacheKey) == newJSON)
    }

    @Test func cachedAnswerIsReturnedWhenOffline() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        storeCachedResponse(context, key: cacheKey, data: oldJSON, now: minute(1))

        let answer = try await fetchWithCacheFallback(
            context, key: cacheKey, fetch: fetchWithoutConnection)

        #expect(answer == oldJSON)
    }

    @Test func errorIsRethrownWhenNothingCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        await #expect(throws: NoConnection.self) {
            try await fetchWithCacheFallback(
                context, key: cacheKey, fetch: fetchWithoutConnection)
        }
    }
}
