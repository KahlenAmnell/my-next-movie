import Foundation

let noYear = 0
let earliestMovieYear = 1880
let yearsAheadOfToday = 5
let maxFilterValues = 3
let yearRangeDash = "\u{2013}"
nonisolated struct MovieFilters: Codable, Equatable {
    let genreIds: [Int]
    let fromYear: Int
    let toYear: Int
    let people: [String]
    let keywords: [String]
    let title: String
}

func yearOfToday() -> Int {
    return Calendar.current.component(.year, from: .now)
}

let noMovieFilters =MovieFilters(
    genreIds: [], fromYear: noYear, toYear: noYear, people: [], keywords: [], title: "")

func validatedFilters(_ filters: MovieFilters, currentYear: Int) -> MovieFilters {
    var fromYear = validatedYear(filters.fromYear, currentYear: currentYear)
    var toYear = validatedYear(filters.toYear, currentYear: currentYear)
    if fromYear != noYear && toYear != noYear && fromYear > toYear {
        swap(&fromYear, &toYear)
    }
    return MovieFilters(
        genreIds: validatedGenreIds(filters.genreIds),
        fromYear: fromYear,
        toYear: toYear,
        people: validatedNames(filters.people),
        keywords: validatedNames(filters.keywords),
        title: filters.title.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

private func validatedYear(_ year: Int, currentYear: Int) -> Int {
    if year < earliestMovieYear || year > currentYear + yearsAheadOfToday {
        return noYear
    }
    return year
}

private func validatedGenreIds(_ genreIds: [Int]) -> [Int] {
    var validIds: [Int] = []
    for genreId in genreIds {
        let isKnown = positionInGenreTable(genreId) != genreNotInTable
        if isKnown && !validIds.contains(genreId) && validIds.count < maxFilterValues {
            validIds.append(genreId)
        }
    }
    return validIds
}

private func validatedNames(_ names: [String]) -> [String] {
    var validNames: [String] = []
    var seenNames: [String] = []
    for name in names {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if !trimmed.isEmpty && !seenNames.contains(lowercased)
            && validNames.count < maxFilterValues
        {
            validNames.append(trimmed)
            seenNames.append(lowercased)
        }
    }
    return validNames
}

func hasAnyFilter(_ filters: MovieFilters) -> Bool {
    return !filters.genreIds.isEmpty
        || filters.fromYear != noYear
        || filters.toYear != noYear
        || !filters.people.isEmpty
        || !filters.keywords.isEmpty
        || !filters.title.isEmpty
}

func moviesMatchingFilters(_ movies: [Movie], _ filters: MovieFilters) -> [Movie] {
    var matching: [Movie] = []
    for movie in movies {
        if hasAnyGenre(movie, of: filters.genreIds) && isInYears(movie, filters) {
            matching.append(movie)
        }
    }
    return matching
}

private func hasAnyGenre(_ movie: Movie, of genreIds: [Int]) -> Bool {
    if genreIds.isEmpty {
        return true
    }
    for genreId in genreIds {
        if movie.genreIds.contains(genreId) {
            return true
        }
    }
    return false
}

private func isInYears(_ movie: Movie, _ filters: MovieFilters) -> Bool {
    if filters.fromYear == noYear && filters.toYear == noYear {
        return true
    }
    guard let year = Int(releaseYear(movie)) else {
        return false
    }
    let isAfterStart = filters.fromYear == noYear || year >= filters.fromYear
    let isBeforeEnd = filters.toYear == noYear || year <= filters.toYear
    return isAfterStart && isBeforeEnd
}

func filtersSummary(_ filters: MovieFilters) -> String {
    var parts: [String] = []
    for genreId in filters.genreIds {
        parts.append(genreName(genreId))
    }
    let years = yearRangeText(fromYear: filters.fromYear, toYear: filters.toYear)
    if !years.isEmpty {
        parts.append(years)
    }
    parts.append(contentsOf: filters.people)
    parts.append(contentsOf: filters.keywords)
    if !filters.title.isEmpty {
        parts.append(filters.title)
    }
    return parts.joined(separator: textSeparator)
}

/// "1990–1999", "1990 or later", "up to 1999", "" without both years.
func yearRangeText(fromYear: Int, toYear: Int) -> String {
    if fromYear != noYear && toYear != noYear {
        return "\(fromYear)\(yearRangeDash)\(toYear)"
    }
    if fromYear != noYear {
        return "\(fromYear) or later"
    }
    if toYear != noYear {
        return "up to \(toYear)"
    }
    return ""
}
