import Testing

@testable import MyNextMovie

private func movieWith(id: Int, releaseDate: String, genreIds: [Int]) -> Movie {
    return Movie(
        id: id,
        title: "Movie \(id)",
        overview: "",
        releaseDate: releaseDate,
        posterPath: nil,
        voteAverage: 7.0,
        genreIds: genreIds
    )
}

private func idsOf(_ movies: [Movie]) -> [Int] {
    var movieIds: [Int] = []
    for movie in movies {
        movieIds.append(movie.id)
    }
    return movieIds
}

private func filters(genreIds: [Int] = [], fromYear: Int = noYear, toYear: Int = noYear)
    -> MovieFilters
{
    return MovieFilters(
        genreIds: genreIds, fromYear: fromYear, toYear: toYear,
        people: [], keywords: [], title: "")
}

// TODO: Lab 7, task 3. FilteredSearchTests (the six tests with a fake `fetch`) go here.

@MainActor
struct MoviesMatchingFiltersTests {
    private let comedy1995 = movieWith(id: 1, releaseDate: "1995-05-01", genreIds: [genreIdComedy])
    private let drama1999 = movieWith(id: 2, releaseDate: "1999-12-31", genreIds: [genreIdDrama])
    private let horror2005 = movieWith(id: 3, releaseDate: "2005-01-01", genreIds: [genreIdHorror])
    private let noDate = movieWith(id: 4, releaseDate: "", genreIds: [genreIdComedy])

    private var allMovies: [Movie] {
        return [comedy1995, drama1999, horror2005, noDate]
    }

    @Test func withoutGenresAndYearsAllMatch() {
        let found = moviesMatchingFilters(allMovies, noMovieFilters)

        #expect(idsOf(found) == [1, 2, 3, 4])
    }

    @Test func anyOfTheGenresMatches() {
        let found = moviesMatchingFilters(
            allMovies, filters(genreIds: [genreIdComedy, genreIdHorror]))

        #expect(idsOf(found) == [1, 3, 4])
    }

    @Test func movieWithoutYearDoesNotMatchYears() {
        let found = moviesMatchingFilters(allMovies, filters(fromYear: 1990))

        #expect(idsOf(found) == [1, 2, 3])
    }

    @Test func yearsIncludeBothEnds() {
        let found = moviesMatchingFilters(allMovies, filters(fromYear: 1995, toYear: 1999))

        #expect(idsOf(found) == [1, 2])
    }
}
