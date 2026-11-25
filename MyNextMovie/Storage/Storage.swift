import Foundation
import SwiftData

func fetchSavedMovies(_ context: ModelContext, movieId: Int) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in savedMovie.movieId == movieId }
    )
    return (try? context.fetch(descriptor)) ?? []
}

func isMovieSaved(_ context: ModelContext, movieId: Int) -> Bool {
    return !fetchSavedMovies(context, movieId: movieId).isEmpty
}

func toggleSavedMovie(_ context: ModelContext, _ movie: Movie, now: Date) {
    let savedCopies = fetchSavedMovies(context, movieId: movie.id)
    if savedCopies.isEmpty {
        context.insert(SavedMovie(movie: movie, savedAt: now, isInCloud: false))
        return
    }
    for savedCopy in savedCopies {
        if savedCopy.isInCloud {
            context.insert(RemovedSavedMovie(movieId: savedCopy.movieId))
        }
        context.delete(savedCopy)
    }
}

func clearSavedMovies(_ context: ModelContext) {
    for savedMovie in (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? [] {
        context.delete(savedMovie)
    }
    for mark in (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? [] {
        context.delete(mark)
    }
}

func movieFromSaved(_ savedMovie: SavedMovie) -> Movie {
    return Movie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds
    )
}

func moviesFromSaved(_ savedMovies: [SavedMovie]) -> [Movie] {
    return savedMovies.map(movieFromSaved)
}

// MARK: - Search history

let maxSearchHistoryCount = 10

func recordSearch(_ context: ModelContext, query: String, now: Date) {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedQuery.isEmpty {
        return
    }
    if let entry = searchHistoryEntry(context, query: trimmedQuery) {
        entry.searchedAt = now
    } else {
        context.insert(SearchHistoryEntry(query: trimmedQuery, searchedAt: now))
    }
    removeOldSearches(context)
}

func recentSearches(_ context: ModelContext) -> [SearchHistoryEntry] {
    return Array(searchHistoryNewestFirst(context).prefix(maxSearchHistoryCount))
}

func clearSearchHistory(_ context: ModelContext) {
    for entry in searchHistoryNewestFirst(context) {
        context.delete(entry)
    }
}

private func searchHistoryEntry(_ context: ModelContext, query: String) -> SearchHistoryEntry? {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        predicate: #Predicate { entry in entry.query == query }
    )
    return try? context.fetch(descriptor).first
}

private func searchHistoryNewestFirst(_ context: ModelContext) -> [SearchHistoryEntry] {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
}

private func removeOldSearches(_ context: ModelContext) {
    for oldEntry in searchHistoryNewestFirst(context).dropFirst(maxSearchHistoryCount) {
        context.delete(oldEntry)
    }
}

// MARK: - Response cache

func storeCachedResponse(_ context: ModelContext, key: String, data: Data, now: Date) {
    if let storedResponse = findCachedResponse(context, key: key) {
        storedResponse.data = data
        storedResponse.fetchedAt = now
    } else {
        context.insert(CachedResponse(key: key, data: data, fetchedAt: now))
    }
}

func cachedResponseData(_ context: ModelContext, key: String) -> Data {
    return findCachedResponse(context, key: key)?.data ?? Data()
}

func fetchWithCacheFallback(
    _ context: ModelContext,
    key: String,
    fetch: () async throws -> Data
) async throws -> Data {
    do {
        let freshData = try await fetch()
        storeCachedResponse(context, key: key, data: freshData, now: .now)
        return freshData
    } catch {
        let cachedData = cachedResponseData(context, key: key)
        if cachedData.isEmpty {
            throw error
        }
        return cachedData
    }
}

private func findCachedResponse(_ context: ModelContext, key: String) -> CachedResponse? {
    let descriptor = FetchDescriptor<CachedResponse>(
        predicate: #Predicate { response in response.key == key }
    )
    return try? context.fetch(descriptor).first
}
