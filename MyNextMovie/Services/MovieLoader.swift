/// Any function that returns movies.
/// View models take one as a parameter, so tests and previews
/// can pass sample data while the app passes a TMDB request.
typealias MovieLoader = () async throws -> [Movie]
