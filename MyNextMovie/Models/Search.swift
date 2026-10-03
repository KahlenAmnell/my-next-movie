import Foundation

/// Movies whose title or overview contains the query and which have the genre.
/// Case and diacritics are ignored. An empty query or `noGenreId` matches every movie.
func filterMovies(_ movies: [Movie], query: String, genreId: Int) -> [Movie] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    var filteredMovies: [Movie] = []

    for movie in movies {
        if genreId != noGenreId && !movie.genreIds.contains(genreId) {
            continue
        }
        if !trimmedQuery.isEmpty && !movieContainsText(movie, trimmedQuery) {
            continue
        }
        filteredMovies.append(movie)
    }
    return filteredMovies
}

private func movieContainsText(_ movie: Movie, _ searchedText: String) -> Bool {
    if textContains(movie.title, searchedText) || textContains(movie.overview, searchedText) {
        return true
    }
    return false
}

/// Whether `fullText` contains `searchedText`, ignoring case and diacritics.
private func textContains(_ fullText: String, _ searchedText: String) -> Bool {
    let comparisonOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return fullText.range(of: searchedText, options: comparisonOptions) != nil
}
