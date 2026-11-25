import Foundation
import SwiftData

func syncSavedMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    try await removeDeletedMoviesFromAccount(context, cloud: cloud)
    try await receiveMoviesFromAccount(context, cloud: cloud)
    try await sendNewMoviesToAccount(context, cloud: cloud)
}

func cloudMovieFromSaved(_ savedMovie: SavedMovie) -> CloudSavedMovie {
    return CloudSavedMovie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds,
        savedAt: savedMovie.savedAt
    )
}

func movieFromCloud(_ cloudMovie: CloudSavedMovie) -> Movie {
    return Movie(
        id: cloudMovie.id,
        title: cloudMovie.title,
        overview: cloudMovie.overview,
        releaseDate: cloudMovie.releaseDate,
        posterPath: cloudMovie.posterPath,
        voteAverage: cloudMovie.voteAverage,
        genreIds: cloudMovie.genreIds
    )
}

// MARK: - Step 1: removals

private func removeDeletedMoviesFromAccount(
    _ context: ModelContext,
    cloud: SavedMoviesCloud
) async throws {
    for movieId in removedMovieIds(context) {
        try await cloud.removeMovie(movieId)
        deleteRemovalMarks(context, movieId: movieId)
    }
}

// MARK: - Step 2: account to device

private func receiveMoviesFromAccount(
    _ context: ModelContext,
    cloud: SavedMoviesCloud
) async throws {
    let cloudMovies = try await cloud.fetchMovies()
    let removedIds = Set(removedMovieIds(context))
    let cloudIds = Set(cloudMovies.map(\.id))

    deleteMoviesMissingFromAccount(context, cloudIds: cloudIds)
    for cloudMovie in cloudMovies where !removedIds.contains(cloudMovie.id) {
        storeMovieFromAccount(context, cloudMovie)
    }
}

private func deleteMoviesMissingFromAccount(_ context: ModelContext, cloudIds: Set<Int>) {
    for savedMovie in allSavedMovies(context) {
        if savedMovie.isInCloud && !cloudIds.contains(savedMovie.movieId) {
            context.delete(savedMovie)
        }
    }
}

private func storeMovieFromAccount(_ context: ModelContext, _ cloudMovie: CloudSavedMovie) {
    if let savedMovie = fetchSavedMovies(context, movieId: cloudMovie.id).first {
        savedMovie.isInCloud = true
        return
    }
    context.insert(
        SavedMovie(
            movie: movieFromCloud(cloudMovie),
            savedAt: cloudMovie.savedAt,
            isInCloud: true
        )
    )
}

// MARK: - Step 3: device to account

private func sendNewMoviesToAccount(
    _ context: ModelContext,
    cloud: SavedMoviesCloud
) async throws {
    let newMovies = unsentSavedMovies(context).map(cloudMovieFromSaved)
    if newMovies.isEmpty {
        return
    }
    try await cloud.uploadMovies(newMovies)
    markAsSent(context, movieIds: newMovies.map(\.id))
}

/// A movie removed while it was being sent is now on the account, so it gets a
/// removal mark and the next sync removes it from there too.
private func markAsSent(_ context: ModelContext, movieIds: [Int]) {
    for movieId in movieIds {
        if let savedMovie = fetchSavedMovies(context, movieId: movieId).first {
            savedMovie.isInCloud = true
        } else {
            context.insert(RemovedSavedMovie(movieId: movieId))
        }
    }
}

// MARK: - Reading the database

private func allSavedMovies(_ context: ModelContext) -> [SavedMovie] {
    return (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
}

private func unsentSavedMovies(_ context: ModelContext) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in !savedMovie.isInCloud }
    )
    return (try? context.fetch(descriptor)) ?? []
}

private func removedMovieIds(_ context: ModelContext) -> [Int] {
    let marks = (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? []
    return marks.map(\.movieId)
}

private func deleteRemovalMarks(_ context: ModelContext, movieId: Int) {
    let descriptor = FetchDescriptor<RemovedSavedMovie>(
        predicate: #Predicate { mark in mark.movieId == movieId }
    )
    for mark in (try? context.fetch(descriptor)) ?? [] {
        context.delete(mark)
    }
}
