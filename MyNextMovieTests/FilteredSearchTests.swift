import Foundation
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

private let emptyPage = #"{"results": []}"#

private func idPage(_ id: Int) -> String {
    return #"{"results": [{"id": \#(id)}]}"#
}

private func moviePage(_ movies: [Movie]) -> String {
    var items: [String] = []
    for movie in movies {
        items.append(
            """
            {"id": \(movie.id), "title": "\(movie.title)", \
            "release_date": "\(movie.releaseDate)", "vote_average": 7.0, \
            "genre_ids": \(movie.genreIds)}
            """)
    }
    return #"{"results": [\#(items.joined(separator: ","))]}"#
}

private func queryOf(_ request: TMDBRequest) -> String {
    for item in request.parameters where item.name == TMDBAPI.queryParamQuery {
        return item.value ?? ""
    }
    return ""
}
@MainActor
private final class FakeTMDB {
    var requests: [TMDBRequest] = []
    var answers: [String: String] = [:]

    func answer(path: String, name: String = "", with json: String) {
        answers[path + "|" + name] = json
    }

    func fetch(_ request: TMDBRequest) async throws -> Data {
        requests.append(request)
        let json = answers[request.path + "|" + queryOf(request)] ?? emptyPage
        return Data(json.utf8)
    }

    func paths() -> [String] {
        var requestPaths: [String] = []
        for request in requests {
            requestPaths.append(request.path)
        }
        return requestPaths
    }
}

private func personAndKeywordFilters(
    people: [String] = [], keywords: [String] = [], genreIds: [Int] = []
) -> MovieFilters {
    return MovieFilters(
        genreIds: genreIds, fromYear: noYear, toYear: noYear,
        people: people, keywords: keywords, title: "")
}

@MainActor
struct FilteredSearchTests {
    private let comedy1995 = movieWith(id: 1, releaseDate: "1995-05-01", genreIds: [genreIdComedy])

    @Test func namesBecomeIdsInOneDiscoverRequest() async throws {
        let tmdb = FakeTMDB()
        tmdb.answer(path: tmdbPathSearchPeople, name: "Keanu Reeves", with: idPage(6384))
        tmdb.answer(path: tmdbPathSearchKeywords, name: "heist", with: idPage(10051))
        tmdb.answer(path: tmdbPathDiscoverMovies, with: moviePage([comedy1995]))
        let filters = personAndKeywordFilters(
            people: ["Keanu Reeves"], keywords: ["heist"], genreIds: [genreIdComedy])

        let found = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(idsOf(found) == [1])
        #expect(tmdb.requests.count == 3)
        #expect(
            tmdb.requests.last
                == tmdbDiscoverRequest(filters, personIds: [6384], keywordIds: [10051]))
    }

    @Test func looksUpEveryNameAtOnce() async throws {
        let tmdb = FakeTMDB()
        tmdb.answer(path: tmdbPathSearchPeople, name: "A", with: idPage(1))
        tmdb.answer(path: tmdbPathSearchPeople, name: "B", with: idPage(2))
        tmdb.answer(path: tmdbPathSearchKeywords, name: "x", with: idPage(3))
        tmdb.answer(path: tmdbPathSearchKeywords, name: "y", with: idPage(4))
        let filters = personAndKeywordFilters(people: ["A", "B"], keywords: ["x", "y"])

        _ = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(tmdb.requests.count == 5)
        #expect(tmdb.paths().last == tmdbPathDiscoverMovies)
        #expect(
            tmdb.requests.last
                == tmdbDiscoverRequest(filters, personIds: [1, 2], keywordIds: [3, 4]))
    }

    @Test func unknownPersonFindsNothing() async throws {
        let tmdb = FakeTMDB()
        let filters = personAndKeywordFilters(people: ["Nobody"], genreIds: [genreIdComedy])

        let found = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(found.isEmpty)
        #expect(!tmdb.paths().contains(tmdbPathDiscoverMovies))
    }

    @Test func onlyUnknownKeywordsFindNothing() async throws {
        let tmdb = FakeTMDB()
        let filters = personAndKeywordFilters(keywords: ["nonsense"])

        let found = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(found.isEmpty)
        #expect(!tmdb.paths().contains(tmdbPathDiscoverMovies))
    }

    @Test func unknownKeywordNextToGenreStillSearches() async throws {
        let tmdb = FakeTMDB()
        tmdb.answer(path: tmdbPathDiscoverMovies, with: moviePage([comedy1995]))
        let filters = personAndKeywordFilters(keywords: ["nonsense"], genreIds: [genreIdComedy])

        let found = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(idsOf(found) == [1])
        #expect(tmdb.requests.last == tmdbDiscoverRequest(filters, personIds: [], keywordIds: []))
    }

    @Test func titleSearchKeepsYearsAndGenres() async throws {
        let tmdb = FakeTMDB()
        let action1994 = movieWith(id: 1, releaseDate: "1994-06-10", genreIds: [genreIdAction])
        let action2005 = movieWith(id: 2, releaseDate: "2005-01-01", genreIds: [genreIdAction])
        let drama1994 = movieWith(id: 3, releaseDate: "1994-01-01", genreIds: [genreIdDrama])
        tmdb.answer(
            path: TMDBAPI.searchPath, name: "Speed",
            with: moviePage([action1994, action2005, drama1994]))
        let filters = MovieFilters(
            genreIds: [genreIdAction], fromYear: 1990, toYear: 1999,
            people: [], keywords: [], title: "Speed")

        let found = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(idsOf(found) == [1])
        #expect(tmdb.paths() == [TMDBAPI.searchPath])
    }
}

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
