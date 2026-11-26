import Foundation
import SwiftData

enum TMDBAPI {
    static let scheme = "https"
    static let host = "api.themoviedb.org"
    // Paths
    static let popularPath = "/3/movie/popular"
    static let searchPath = "/3/search/movie"
    static let discoverPath = "/3/discover/movie"
    static let moviePath = "/3/movie"
    // Query parameters
    static let queryParamApiKey = "api_key"
    static let queryParamQuery = "query"
    static let queryParamGenres = "with_genres"
    static let queryParamAppend = "append_to_response"
    static let queryParamPeople = "with_people"
    static let queryParamKeywords = "with_keywords"
    static let queryParamFromDate = "primary_release_date.gte"
    static let queryParamToDate = "primary_release_date.lte"
    // HTTP codes
    static let httpStatusOK = 200
    static let httpStatusUnauthorized = 401
}

nonisolated struct TMDBMoviePage: Decodable, Sendable {
    let results: [Movie]
}

typealias TMDBMovieResponse = TMDBMoviePage
typealias TMDBMovie = Movie

nonisolated enum TMDBError: LocalizedError {
    case message(String)
    case invalidURL
    case requestFailed(statusCode: Int?)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        case .invalidURL:
            return "Invalid URL generated for TMDB request."
        case .requestFailed(let statusCode):
            if let code = statusCode {
                return "Server returned unexpected status code: \(code)"
            } else {
                return "Request failed."
            }
        }
    }
}

func tmdbURL(path: String, parameters: [String: String], apiKey: String) -> URL? {
    var queryItems: [URLQueryItem] = []
    for (key, value) in parameters {
        queryItems.append(URLQueryItem(name: key, value: value))
    }
    return tmdbURL(path: path, parameters: queryItems, apiKey: apiKey)
}

func tmdbURL(path: String, parameters: [URLQueryItem], apiKey: String) -> URL? {
    var components = URLComponents()
    components.scheme = TMDBAPI.scheme
    components.host = TMDBAPI.host
    components.path = path
    components.queryItems = [URLQueryItem(name: TMDBAPI.queryParamApiKey, value: apiKey)] + parameters
    return components.url
}

func tmdbPopularURL(apiKey: String) -> URL? {
    return tmdbURL(path: TMDBAPI.popularPath, parameters: [:], apiKey: apiKey)
}

func tmdbSearchURL(query: String, genreId: Int = 0, apiKey: String) -> URL? {
    var params: [String: String] = [:]
    if !query.isEmpty {
        params[TMDBAPI.queryParamQuery] = query
        return tmdbURL(path: TMDBAPI.searchPath, parameters: params, apiKey: apiKey)
    } else {
        if genreId > 0 {
            params[TMDBAPI.queryParamGenres] = String(genreId)
        }
        return tmdbURL(path: TMDBAPI.discoverPath, parameters: params, apiKey: apiKey)
    }
}

func tmdbDiscoverURL(genreID: Int, apiKey: String) -> URL? {
    let params = [TMDBAPI.queryParamGenres: String(genreID)]
    return tmdbURL(path: TMDBAPI.discoverPath, parameters: params, apiKey: apiKey)
}

func tmdbDetailsURL(movieID: Int, appendParts: [String], apiKey: String) -> URL? {
    let path = "\(TMDBAPI.moviePath)/\(movieID)"
    var params: [String: String] = [:]
    if !appendParts.isEmpty {
        params[TMDBAPI.queryParamAppend] = appendParts.joined(separator: ",")
    }
    return tmdbURL(path: path, parameters: params, apiKey: apiKey)
}

nonisolated func decodeTMDBMovies(_ data: Data) throws -> [Movie] {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let page = try decoder.decode(TMDBMoviePage.self, from: data)
    return page.results
}

func filterTMDBMovies(_ movies: [Movie], query: String, genreId: Int) -> [Movie] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return movies.filter { movie in
        let matchesQuery = trimmedQuery.isEmpty || movie.title.localizedCaseInsensitiveContains(trimmedQuery)
        let matchesGenre = genreId <= 0 || (movie.genreIds.contains(genreId))
        return matchesQuery && matchesGenre
    }
}

func checkTMDBResponse(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else { return }

    if httpResponse.statusCode == TMDBAPI.httpStatusUnauthorized {
        throw TMDBError.message("Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    guard httpResponse.statusCode == TMDBAPI.httpStatusOK else {
        throw TMDBError.requestFailed(statusCode: httpResponse.statusCode)
    }
}

protocol URLSessionProtocol {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

private func fetchTMDBData(
    _ address: URL?, session: URLSessionProtocol = URLSession.shared
)

async throws -> Data {
    guard let url = address else {
        throw TMDBError.invalidURL
    }

    let (data, response) = try await session.data(from: url)
    try checkTMDBResponse(response)

    return data
}

/// Raw JSON of the popular movies, the part that needs internet.
func fetchPopularMoviesData() async throws -> Data {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError.message("Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    let url = tmdbPopularURL(apiKey: apiKey)
    return try await fetchTMDBData(url)
}

func fetchPopularMovies() async throws -> [Movie] {
    let data = try await fetchPopularMoviesData()
    return try decodeTMDBMovies(data)
}

func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError.message("Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }

    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let url = tmdbSearchURL(query: trimmedQuery, genreId: genreId, apiKey: apiKey)
    let data = try await fetchTMDBData(url)
    let movies = try decodeTMDBMovies(data)
    return filterTMDBMovies(movies, query: "", genreId: genreId)
}

func tmdbMovieDetailsURL(movieId: Int, apiKey: String) -> URL? {
    var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(movieId)")
    components?.queryItems = [
        URLQueryItem(name: "api_key", value: apiKey),
        URLQueryItem(name: "append_to_response", value: "credits,videos,release_dates,watch/providers,recommendations")
    ]
    return components?.url
}

func decodeTMDBMovieDetails(_ data: Data) throws -> MovieDetails {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(MovieDetails.self, from: data)
}

/// Raw JSON of the movie details, the part that needs internet.
func fetchMovieDetailsData(movieId: Int) async throws -> Data {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError.message("Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    guard let url = tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey) else {
        throw TMDBError.invalidURL
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw TMDBError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode)
    }
    return data
}

func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let data = try await fetchMovieDetailsData(movieId: movieId)
    return try decodeTMDBMovieDetails(data)
}

// MARK: - Loading with a cache on the device

let popularMoviesCacheKey = "popular"

func movieDetailsCacheKey(movieId: Int) -> String {
    return "movie/\(movieId)"
}

/// Like `fetchPopularMovies`, but without internet it uses the last stored answer.
func loadPopularMovies(cache: ModelContext) async throws -> [Movie] {
    let data = try await fetchWithCacheFallback(cache, key: popularMoviesCacheKey) {
        try await fetchPopularMoviesData()
    }
    return try decodeTMDBMovies(data)
}

/// Like `fetchMovieDetails`, but without internet it uses the last stored answer.
func loadTMDBMovieDetails(movieId: Int, cache: ModelContext) async throws -> MovieDetails {
    let key = movieDetailsCacheKey(movieId: movieId)
    let data = try await fetchWithCacheFallback(cache, key: key) {
        try await fetchMovieDetailsData(movieId: movieId)
    }
    return try decodeTMDBMovieDetails(data)
}

// MARK: - Search by filters (AI search)

let tmdbPathDiscoverMovies = "/3/discover/movie"
let tmdbPathSearchPeople = "/3/search/person"
let tmdbPathSearchKeywords = "/3/search/keyword"
let noTMDBId = 0

nonisolated struct TMDBRequest: Equatable {
    let path: String
    let parameters: [URLQueryItem]
}

typealias TMDBFetch =
    @MainActor (_ request: TMDBRequest) async throws -> Data

func requireTMDBAPIKey() throws -> String {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError.message("Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    return apiKey
}

func fetchTMDBRequest(_ request: TMDBRequest) async throws -> Data {
    let apiKey = try requireTMDBAPIKey()
    let address = tmdbURL(
        path: request.path,
        parameters: request.parameters, apiKey: apiKey)
    return try await fetchTMDBData(address)
}

func searchTMDBMoviesByFilters(_ filters: MovieFilters) async throws -> [Movie] {
    return try await searchMoviesByFilters(filters, fetch: fetchTMDBRequest)
}

func searchMoviesByFilters(_ filters: MovieFilters, fetch: TMDBFetch) async throws -> [Movie] {
    if !filters.title.isEmpty {
        return try await searchMoviesByTitle(filters, fetch: fetch)
    }
    async let foundPersonIds = lookUpTMDBIds(
        path: tmdbPathSearchPeople, names: filters.people, fetch: fetch)
    async let foundKeywordIds = lookUpTMDBIds(
        path: tmdbPathSearchKeywords, names: filters.keywords, fetch: fetch)
    let personIds = try await foundPersonIds
    let keywordIds = knownTMDBIds(try await foundKeywordIds)

    let hasUnknownPerson = personIds.contains(noTMDBId)
    let hasAnythingToAsk =
        !filters.genreIds.isEmpty || filters.fromYear != noYear || filters.toYear != noYear
        || !personIds.isEmpty || !keywordIds.isEmpty
    if hasUnknownPerson || !hasAnythingToAsk {
        return []
    }
    let request = tmdbDiscoverRequest(filters, personIds: personIds, keywordIds: keywordIds)
    return try decodeTMDBMovies(try await fetch(request))
}

private func searchMoviesByTitle(_ filters: MovieFilters, fetch: TMDBFetch) async throws
    -> [Movie]
{
    let request = tmdbNameSearchRequest(path: TMDBAPI.searchPath, name: filters.title)
    let movies = try decodeTMDBMovies(try await fetch(request))
    return moviesMatchingFilters(movies, filters)
}

private func lookUpTMDBIds(path: String, names: [String], fetch: TMDBFetch) async throws
    -> [Int]
{
    return try await withThrowingTaskGroup(of: (position: Int, id: Int).self) { group in
        for (position, name) in names.enumerated() {
            group.addTask {
                let request = tmdbNameSearchRequest(path: path, name: name)
                return (position, try decodeFirstTMDBId(try await fetch(request)))
            }
        }
        var ids = Array(repeating: noTMDBId, count: names.count)
        for try await found in group {
            ids[found.position] = found.id
        }
        return ids
    }
}

private func knownTMDBIds(_ ids: [Int]) -> [Int] {
    var known: [Int] = []
    for id in ids where id != noTMDBId {
        known.append(id)
    }
    return known
}

nonisolated func tmdbDiscoverRequest(
    _ filters: MovieFilters, personIds: [Int], keywordIds: [Int]
) -> TMDBRequest {
    var parameters: [URLQueryItem] = []
    appendIds(&parameters, TMDBAPI.queryParamGenres, filters.genreIds, separator: "|")
    appendIds(&parameters, TMDBAPI.queryParamPeople, personIds, separator: ",")
    appendIds(&parameters, TMDBAPI.queryParamKeywords, keywordIds, separator: "|")
    if filters.fromYear != noYear {
        parameters.append(
            URLQueryItem(name: TMDBAPI.queryParamFromDate, value: "\(filters.fromYear)-01-01"))
    }
    if filters.toYear != noYear {
        parameters.append(
            URLQueryItem(name: TMDBAPI.queryParamToDate, value: "\(filters.toYear)-12-31"))
    }
    return TMDBRequest(path: tmdbPathDiscoverMovies, parameters: parameters)
}

private nonisolated func appendIds(
    _ parameters: inout [URLQueryItem], _ name: String, _ ids: [Int], separator: String
) {
    if ids.isEmpty {
        return
    }
    var texts: [String] = []
    for id in ids {
        texts.append(String(id))
    }
    parameters.append(URLQueryItem(name: name, value: texts.joined(separator: separator)))
}

nonisolated func tmdbNameSearchRequest(path: String, name: String) -> TMDBRequest {
    return TMDBRequest(
        path: path, parameters: [URLQueryItem(name: TMDBAPI.queryParamQuery, value: name)])
}

private nonisolated struct TMDBIdPage: Decodable {
    let results: [TMDBIdResult]
}

private nonisolated struct TMDBIdResult: Decodable {
    let id: Int
}

nonisolated func decodeFirstTMDBId(_ data: Data) throws -> Int {
    let page = try JSONDecoder().decode(TMDBIdPage.self, from: data)
    return page.results.first?.id ?? noTMDBId
}
