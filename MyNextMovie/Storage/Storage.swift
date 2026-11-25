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
        context.insert(SavedMovie(movie: movie, savedAt: now))
        return
    }
    for savedCopy in savedCopies {
        context.delete(savedCopy)
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
