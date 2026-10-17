import Foundation

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
    // HTTP codes
    static let httpStatusOK = 200
    static let httpStatusUnauthorized = 401
}

nonisolated struct TMDBMoviePage: Decodable, Sendable {
    let results: [Movie]
}

typealias TMDBMovieResponse = TMDBMoviePage
typealias TMDBMovie = Movie

nonisolated struct TMDBError: LocalizedError {
    let message: String
    var errorDescription: String? {
        return message
    }
}

func tmdbURL(path: String, parameters: [String: String], apiKey: String) -> URL? {
    var components = URLComponents()
    components.scheme = TMDBAPI.scheme
    components.host = TMDBAPI.host
    components.path = path
    var queryItems = [URLQueryItem(name: TMDBAPI.queryParamApiKey, value: apiKey)]
    for (key, value) in parameters {
        queryItems.append(URLQueryItem(name: key, value: value))
    }
    components.queryItems = queryItems
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
        throw TMDBError(message: "Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    guard httpResponse.statusCode == TMDBAPI.httpStatusOK else {
        throw TMDBError(message: "Server returned unexpected status code: \(httpResponse.statusCode)")
    }
}

protocol URLSessionProtocol {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

private func fetchTMDBData(_ address: URL?, session: URLSessionProtocol = URLSession.shared) async throws -> Data {
    guard let url = address else {
        throw TMDBError(message: "Invalid URL generated for TMDB request.")
    }
    
    let (data, response) = try await session.data(from: url)
    try checkTMDBResponse(response)
    
    return data
}

func fetchPopularMovies() async throws -> [Movie] {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError(message: "Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    let url = tmdbPopularURL(apiKey: apiKey)
    let data = try await fetchTMDBData(url)
    return try decodeTMDBMovies(data)
}

func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError(message: "Missing TMDB API key. Add it to Config/Secrets.xcconfig.")
    }
    
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let url = tmdbSearchURL(query: trimmedQuery, genreId: genreId, apiKey: apiKey)
    let data = try await fetchTMDBData(url)
    let movies = try decodeTMDBMovies(data)
    
    return filterMovies(movies, query: trimmedQuery, genreId: genreId)
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

func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    guard let url = tmdbMovieDetailsURL(movieId: movieId, apiKey: tmdbApiKey) else {
        throw TMDBError.invalidURL
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw TMDBError.requestFailed
    }
    return try decodeTMDBMovieDetails(data)
}
