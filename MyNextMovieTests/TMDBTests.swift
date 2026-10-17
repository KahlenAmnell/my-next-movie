import Testing
import Foundation
@testable import MyNextMovie

@MainActor
@Suite struct TMDBTests {

private let sampleJSON = """
    {
        "page": 1,
        "results": [
            {
                "id": 603,
                "title": "The Matrix",
                "release_date": "1999-03-31",
                "poster_path": "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
                "vote_average": 8.7,
                "genre_ids": [12, 28, 878]
            }
        ],
        "total_pages": 1,
        "total_results": 1
    }
    """

    @Test func decodesSnakeCaseKeys() throws {
        let data = Data(sampleJSON.utf8)
        let decoder = JSONDecoder()

        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(TMDBMovieResponse.self, from: data)
        let movie = try #require(response.results.first)

        #expect(movie.releaseDate == "1999-03-31")
        #expect(movie.posterPath == "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg")
        #expect(movie.voteAverage == 8.7)
        #expect(movie.genreIds == [12, 28, 878])
    }

    @Test func decodesMissingPosterAsNil() throws {
        let jsonWithoutPoster = """
        {
            "id": 603,
            "title": "The Matrix",
            "release_date": "1999-03-31",
            "poster_path": null,
            "vote_average": 8.7,
            "genre_ids": [28]
        }
        """
        let data = Data(jsonWithoutPoster.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let movie = try decoder.decode(TMDBMovie.self, from: data)
        #expect(movie.posterPath == nil)
    }

    @Test func decodingFailsForOtherJSON() {
        let otherJSON = """
        {
            "status_code": 7,
            "status_message": "Invalid API key"
        }
        """
        let data = Data(otherJSON.utf8)
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(TMDBMovieResponse.self, from: data)
        }
    }

    @Test func popularURLHasAPIKey() throws {
        let url = try #require(tmdbPopularURL(apiKey: "test-key"))
        #expect(url.absoluteString == "https://api.themoviedb.org/3/movie/popular?api_key=test-key")
    }

    @Test func searchWithTextUsesSearchEndpoint() throws {
        let url = try #require(tmdbSearchURL(query: "Matrix", apiKey: "test-key"))
        #expect(url.path() == "/3/search/movie")
        
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = try #require(components.queryItems)
        #expect(queryItems.contains(URLQueryItem(name: "query", value: "Matrix")))
    }

    @Test func searchWithGenreOnlyUsesDiscoverEndpoint() throws {
        let url = try #require(tmdbDiscoverURL(genreID: 16, apiKey: "test-key")) // Przykład dla Animation / genreID
        #expect(url.path() == "/3/discover/movie")
        
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = try #require(components.queryItems)
        #expect(queryItems.contains(URLQueryItem(name: "with_genres", value: "16")))
    }

    @Test func searchTextIsPercentEncoded() throws {
        let url = try #require(tmdbSearchURL(query: "pan tadeusz", apiKey: "test-key"))
        #expect(url.absoluteString.contains("query=pan%20tadeusz"))
    }

    @Test func detailsURLAppendsEveryPart() throws {
        let url = try #require(tmdbDetailsURL(movieID: 603, appendParts: ["credits", "videos"], apiKey: "test-key"))
        #expect(url.path() == "/3/movie/603")
        
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = try #require(components.queryItems)
        #expect(queryItems.contains(URLQueryItem(name: "append_to_response", value: "credits,videos")))
    }

    @Test func okResponsePasses() throws {
        let url = try #require(URL(string: "https://api.themoviedb.org"))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        
        #expect(throws: Never.self) {
            try checkTMDBResponse(response)
        }
    }

    @Test func unauthorizedResponseMentionsAPIKey() throws {
        let url = try #require(URL(string: "https://api.themoviedb.org"))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil))
        
        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        
        let errorMessage = String(describing: thrownError)
        #expect(errorMessage.localizedStandardContains("API key"))
    }

    @Test func otherErrorResponseShowsStatus() throws {
        let url = try #require(URL(string: "https://api.themoviedb.org"))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil))
        
        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        
        let errorMessage = String(describing: thrownError)
        #expect(errorMessage.contains("404"))
    }
}
