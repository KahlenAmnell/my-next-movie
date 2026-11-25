import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

/// Pretends to be the `saved_movies` table of one account.
/// A class, so the closures in `SavedMoviesCloud` and the test see the same rows.
@MainActor
private final class TestCloud {
    var movies: [CloudSavedMovie] = []
    var isOffline = false
    var uploadCount = 0

    var cloud: SavedMoviesCloud {
        return SavedMoviesCloud(
            fetchMovies: { [self] in
                try checkConnection()
                return movies
            },
            uploadMovies: { [self] cloudMovies in
                try checkConnection()
                uploadCount += 1
                // Like `upsert` with `ignoreDuplicates`: existing rows stay as they are.
                let knownIds = Set(movies.map(\.id))
                movies += cloudMovies.filter { !knownIds.contains($0.id) }
            },
            removeMovie: { [self] movieId in
                try checkConnection()
                movies.removeAll { $0.id == movieId }
            }
        )
    }

    var ids: Set<Int> {
        return Set(movies.map(\.id))
    }

    private func checkConnection() throws {
        if isOffline {
            throw NoConnection()
        }
    }
}

private func makeMovie(_ id: Int) -> Movie {
    return Movie(
        id: id,
        title: "Movie \(id)",
        overview: "Overview \(id)",
        releaseDate: "2000-01-01",
        posterPath: "/poster\(id).jpg",
        voteAverage: 7.5,
        genreIds: [18, 35]
    )
}

private func makeCloudMovie(_ id: Int, savedAt: Date = Date(timeIntervalSince1970: 0))
    -> CloudSavedMovie
{
    return CloudSavedMovie(
        id: id,
        title: "Movie \(id)",
        overview: "Overview \(id)",
        releaseDate: "2000-01-01",
        posterPath: "/poster\(id).jpg",
        voteAverage: 7.5,
        genreIds: [18, 35],
        savedAt: savedAt
    )
}

private let startTime = Date(timeIntervalSince1970: 0)

@MainActor
private func deviceIds(_ context: ModelContext) throws -> Set<Int> {
    return Set(try context.fetch(FetchDescriptor<SavedMovie>()).map(\.movieId))
}

@MainActor
private func markIds(_ context: ModelContext) throws -> Set<Int> {
    return Set(try context.fetch(FetchDescriptor<RemovedSavedMovie>()).map(\.movieId))
}

@MainActor
struct SavedMoviesSyncTests {
    @Test func movieSavedOnDeviceGoesToAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        toggleSavedMovie(context, makeMovie(1), now: startTime)

        try await syncSavedMovies(context, cloud: account.cloud)

        #expect(account.ids == [1])
        #expect(fetchSavedMovies(context, movieId: 1).first?.isInCloud == true)
    }

    @Test func movieIsSentOnlyOnce() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        toggleSavedMovie(context, makeMovie(1), now: startTime)

        try await syncSavedMovies(context, cloud: account.cloud)
        try await syncSavedMovies(context, cloud: account.cloud)

        #expect(account.uploadCount == 1)
    }

    @Test func movieFromAccountComesToDevice() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        let accountDate = startTime.addingTimeInterval(500)
        account.movies = [makeCloudMovie(1, savedAt: accountDate)]

        try await syncSavedMovies(context, cloud: account.cloud)

        let savedMovie = fetchSavedMovies(context, movieId: 1).first
        #expect(savedMovie?.isInCloud == true)
        #expect(savedMovie?.savedAt == accountDate)
        #expect(savedMovie.map(movieFromSaved) == makeMovie(1))
    }

    @Test func deviceAndAccountListsAreMerged() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        account.movies = [makeCloudMovie(2)]
        toggleSavedMovie(context, makeMovie(1), now: startTime)

        try await syncSavedMovies(context, cloud: account.cloud)

        #expect(try deviceIds(context) == [1, 2])
        #expect(account.ids == [1, 2])
    }

    @Test func movieRemovedOnDeviceIsRemovedFromAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        toggleSavedMovie(context, makeMovie(1), now: startTime)
        try await syncSavedMovies(context, cloud: account.cloud)

        toggleSavedMovie(context, makeMovie(1), now: startTime)
        try await syncSavedMovies(context, cloud: account.cloud)

        #expect(account.ids.isEmpty)
        #expect(try deviceIds(context).isEmpty)
        #expect(try markIds(context).isEmpty)
    }

    @Test func movieRemovedOnAnotherDeviceIsRemovedHere() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        toggleSavedMovie(context, makeMovie(1), now: startTime)
        try await syncSavedMovies(context, cloud: account.cloud)

        account.movies = []
        try await syncSavedMovies(context, cloud: account.cloud)

        #expect(try deviceIds(context).isEmpty)
        #expect(try markIds(context).isEmpty)
    }

    @Test func changesMadeOfflineAreSentWithTheNextSync() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        toggleSavedMovie(context, makeMovie(1), now: startTime)
        try await syncSavedMovies(context, cloud: account.cloud)

        account.isOffline = true
        toggleSavedMovie(context, makeMovie(1), now: startTime)
        toggleSavedMovie(context, makeMovie(2), now: startTime)
        await #expect(throws: NoConnection.self) {
            try await syncSavedMovies(context, cloud: account.cloud)
        }
        #expect(account.ids == [1])

        account.isOffline = false
        try await syncSavedMovies(context, cloud: account.cloud)

        #expect(account.ids == [2])
        #expect(try deviceIds(context) == [2])
    }

    @Test func movieRemovedAndSavedAgainOfflineStays() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let account = TestCloud()
        toggleSavedMovie(context, makeMovie(1), now: startTime)
        try await syncSavedMovies(context, cloud: account.cloud)

        let newDate = startTime.addingTimeInterval(1000)
        toggleSavedMovie(context, makeMovie(1), now: startTime)
        toggleSavedMovie(context, makeMovie(1), now: newDate)
        try await syncSavedMovies(context, cloud: account.cloud)

        #expect(account.movies.map(\.id) == [1])
        #expect(account.movies.first?.savedAt == newDate)
        #expect(try deviceIds(context) == [1])
        #expect(try markIds(context).isEmpty)
    }
}

struct CloudSavedMovieTests {
    @Test func encodesColumnNamesInSnakeCase() throws {
        let data = try JSONEncoder().encode(makeCloudMovie(1))

        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let expectedKeys: Set<String> = [
            "id", "title", "overview", "release_date", "poster_path",
            "vote_average", "genre_ids", "saved_at",
        ]
        #expect(Set(json.keys) == expectedKeys)
    }

    @MainActor
    @Test func cloudCopyKeepsEveryMovieField() {
        let movie = makeMovie(603)
        let savedMovie = SavedMovie(movie: movie, savedAt: startTime, isInCloud: false)

        let copy = movieFromCloud(cloudMovieFromSaved(savedMovie))

        #expect(copy == movie)
    }
}
