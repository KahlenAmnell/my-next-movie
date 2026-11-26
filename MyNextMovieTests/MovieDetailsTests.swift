import Testing
import XCTest
@testable import MyNextMovie

@MainActor
final class MovieDetailsDecodingTests: XCTestCase {

    let matrixJSON = """
    {
        "id": 603,
        "tagline": "Believe the unbelievable.",
        "runtime": 136,
        "credits": {
            "cast": [
                {"id": 6384, "name": "Keanu Reeves", "character": "Neo", "profile_path": "/8RZL.jpg"},
                {"id": 1234, "name": "No Photo Actor", "character": "Unknown", "profile_path": null}
            ],
            "crew": [
                {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
                {"id": 9340, "name": "Lana Wachowski", "job": "Director"}
            ]
        },
        "videos": {
            "results": [
                {"key": "unofficialKey", "site": "YouTube", "type": "Trailer", "official": false},
                {"key": "vKQi3bBA1y8", "site": "YouTube", "type": "Trailer", "official": true}
            ]
        },
        "release_dates": {
            "results": [
                {"iso_3166_1": "PL", "release_dates": [{"certification": "", "release_date": "1999-03-31T00:00:00.000Z", "type": 3}, {"certification": "16", "release_date": "1999-03-31T00:00:00.000Z", "type": 3}]}
            ]
        },
        "watch/providers": {
            "results": {
                "PL": {
                    "link": "https://www.themoviedb.org/movie/603-the-matrix/watch?locale=PL",
                    "flatrate": [{"provider_id": 119, "provider_name": "Amazon Prime Video", "logo_path": "/gMZd.png"}],
                    "rent": [{"provider_id": 2, "provider_name": "Apple TV", "logo_path": "/apple.png"}],
                    "buy": null
                }
            }
        },
        "recommendations": {
            "results": [
                {"id": 604, "title": "The Matrix Reloaded", "overview": "Test", "poster_path": nil, "backdrop_path": nil, "vote_average": 7.0, "release_date": "2003-05-15"}
            ]
        }
    }
    """.data(using: .utf8)!
    
    let announcedJSON = """
    {
        "id": 999,
        "tagline": null,
        "runtime": null,
        "credits": null,
        "videos": null,
        "release_dates": null,
        "watch/providers": null,
        "recommendations": null
    }
    """.data(using: .utf8)!
    
    func testDecodesTaglineAndRuntime() throws {
        let details = try decodeTMDBMovieDetails(matrixJSON)
        XCTAssertEqual(details.tagline, "Believe the unbelievable.")
        XCTAssertEqual(details.runtime, 136)
    }
    
    func testDecodesCastWithAndWithoutPhoto() throws {
        let details = try decodeTMDBMovieDetails(matrixJSON)
        let cast = details.credits?.cast
        XCTAssertEqual(cast?[0].profilePath, "/8RZL.jpg")
        XCTAssertNil(cast?[1].profilePath)
    }
    
    func testDecodesWatchProvidersUnderSlashKey() throws {
        let details = try decodeTMDBMovieDetails(matrixJSON)
        let plProviders = details.watchProviders?.results?["PL"]
        XCTAssertNotNil(plProviders?.flatrate)
        XCTAssertNotNil(plProviders?.rent)
        XCTAssertNil(plProviders?.buy)
    }
    
    func testDecodesCountryCodeOfReleaseDates() throws {
        let details = try decodeTMDBMovieDetails(matrixJSON)
        XCTAssertEqual(details.releaseDates?.results?[0].countryCode, "PL")
    }
    
    func testDecodesRecommendationsAsMovies() throws {
        let details = try decodeTMDBMovieDetails(matrixJSON)
        XCTAssertEqual(details.recommendations?.results[0].id, 604)
        XCTAssertEqual(details.recommendations?.results[0].title, "The Matrix Reloaded")
    }
    
    func testDecodesAnnouncedMovieWithoutRuntime() throws {
        let details = try decodeTMDBMovieDetails(announcedJSON)
        XCTAssertNil(details.runtime)
        XCTAssertEqual(formattedRuntime(details), "")
        let providers = watchProviders(details, regionCode: "PL")
        XCTAssertFalse(hasWatchProviders(providers))
    }
}

@MainActor
final class MovieDetailsTests: XCTestCase {
    
    func makeMovieDetails(runtime: Int? = nil, videos: [Video]? = nil, crew: [CrewMember]? = nil, releaseDates: [CountryReleaseDates]? = nil) -> MovieDetails {
        MovieDetails(
            id: 1,
            tagline: "Test",
            runtime: runtime,
            credits: Credits(cast: nil, crew: crew),
            videos: VideoList(results: videos),
            releaseDates: ReleaseDateList(results: releaseDates),
            watchProviders: nil,
            recommendations: nil
        )
    }
    
    func testRuntimeInHoursAndMinutes() {
        let d1 = makeMovieDetails(runtime: 136)
        XCTAssertEqual(formattedRuntime(d1), "2h 16m")
        let d2 = makeMovieDetails(runtime: 120)
        XCTAssertEqual(formattedRuntime(d2), "2h 0m")
    }
    
    func testRuntimeUnderAnHourHasOnlyMinutes() {
        let d = makeMovieDetails(runtime: 45)
        XCTAssertEqual(formattedRuntime(d), "45m")
    }
    
    func testRuntimeIsEmptyWhenUnknown() {
        XCTAssertEqual(formattedRuntime(makeMovieDetails(runtime: nil)), "")
        XCTAssertEqual(formattedRuntime(makeMovieDetails(runtime: 0)), "")
    }
    
    func testDirectorsAreListedOnceEach() {
        let crew = [
            CrewMember(id: 1, name: "Lana Wachowski", job: "Director"),
            CrewMember(id: 1, name: "Lana Wachowski", job: "Director"),
            CrewMember(id: 2, name: "Lilly Wachowski", job: "Director")
        ]
        let d = makeMovieDetails(crew: crew)
        let directors = directorNames(d)
        XCTAssertTrue(directors.contains("Lana Wachowski"))
        XCTAssertTrue(directors.contains("Lilly Wachowski"))
    }
    
    func testDirectorsAreEmptyWithoutDirector() {
        let d = makeMovieDetails(crew: [CrewMember(id: 1, name: "John", job: "Producer")])
        XCTAssertEqual(directorNames(d), "")
    }
    
    func testCertificationSkipsEmptyOnes() {
        let releaseDates = [
            CountryReleaseDates(countryCode: "PL", releaseDates: [ReleaseDate(certification: "", releaseDate: "", type: 0), ReleaseDate(certification: "16", releaseDate: "", type: 0)]),
            CountryReleaseDates(countryCode: "US", releaseDates: [ReleaseDate(certification: "R", releaseDate: "", type: 0)])
        ]
        let d = makeMovieDetails(releaseDates: releaseDates)
        XCTAssertEqual(ageCertification(d, regionCode: "PL"), "16")
        XCTAssertEqual(ageCertification(d, regionCode: "US"), "R")
    }
    
    func testCertificationIsEmptyForOtherCountry() {
        let d = makeMovieDetails(releaseDates: [])
        XCTAssertEqual(ageCertification(d, regionCode: "FR"), "")
    }
    
    func testOfficialTrailerWins() {
        let videos = [
            Video(key: "unofficial", site: "YouTube", type: "Trailer", official: false),
            Video(key: "official", site: "YouTube", type: "Trailer", official: true)
        ]
        let d = makeMovieDetails(videos: videos)
        XCTAssertEqual(trailerKey(d), "official")
    }
    
    func testUnofficialTrailerWhenNoOfficial() {
        let videos = [
            Video(key: "unofficial", site: "YouTube", type: "Trailer", official: false)
        ]
        let d = makeMovieDetails(videos: videos)
        XCTAssertEqual(trailerKey(d), "unofficial")
    }
    
    func testTrailerOnOtherSiteIsSkipped() {
        let videos = [
            Video(key: "vimeoKey", site: "Vimeo", type: "Trailer", official: true)
        ]
        let d = makeMovieDetails(videos: videos)
        XCTAssertEqual(trailerKey(d), "")
    }
    
    func testTrailerURLPointsToYouTube() {
        let videos = [Video(key: "abc123xyz", site: "YouTube", type: "Trailer", official: true)]
        let d = makeMovieDetails(videos: videos)
        XCTAssertEqual(trailerURL(d)?.absoluteString, "https://www.youtube.com/watch?v=abc123xyz")
    }
    
    func testFactsLineAddsRuntimeAndCertification() {
        let movie = Movie(id: 1, title: "Matrix", overview: "", releaseDate: "1999-03-31", posterPath: nil, voteAverage: 8.2, genreIds: [])
            let releaseDates = [CountryReleaseDates(countryCode: "PL", releaseDates: [ReleaseDate(certification: "16", releaseDate: "", type: 0)])]
            let d = makeMovieDetails(runtime: 136, releaseDates: releaseDates)
            XCTAssertEqual(movieFactsLine(movie, d, regionCode: "PL"), "1999 · ★ 8.2 · 2h 16m · 16")
        }
        
        func testFactsLineBeforeDetailsLoad() {
            let movie = Movie(id: 1, title: "Matrix", overview: "", releaseDate: "1999-03-31", posterPath: nil, voteAverage: 8.2, genreIds: [])
            XCTAssertEqual(movieFactsLine(movie, emptyMovieDetails, regionCode: "PL"), "1999 · ★ 8.2")
        }
    
    func testProfileURLIsNilWithoutPhoto() {
        let member = CastMember(id: 1, name: "Test", character: "Test", profilePath: nil)
        XCTAssertNil(profileURL(member))
    }
}

// MARK: - Now in cinemas

/// 6 November 2026, the day "today" in these tests.
private let testToday = Date(timeIntervalSince1970: 1_793_923_200)

@MainActor
private func makeDetails(
    country: String = "PL", type: Int = releaseTypeTheatrical, releaseDate: String
) -> MovieDetails {
    let release = ReleaseDate(certification: "", releaseDate: releaseDate, type: type)
    let countryReleases = CountryReleaseDates(countryCode: country, releaseDates: [release])
    return MovieDetails(
        id: 1,
        tagline: nil,
        runtime: nil,
        credits: nil,
        videos: nil,
        releaseDates: ReleaseDateList(results: [countryReleases]),
        watchProviders: nil,
        recommendations: nil
    )
}

@MainActor
private func isInPolishCinemas(_ details: MovieDetails) -> Bool {
    return isInCinemas(details, regionCode: "PL", today: testToday)
}

@MainActor
struct InCinemasTests {
    @Test func recentCinemaPremiereIsInCinemas() {
        let details = makeDetails(releaseDate: "2026-10-17T00:00:00.000Z")

        #expect(isInPolishCinemas(details))
    }

    @Test func limitedReleaseCountsToo() {
        let details = makeDetails(
            type: releaseTypeTheatricalLimited, releaseDate: "2026-10-17T00:00:00.000Z")

        #expect(isInPolishCinemas(details))
    }

    @Test func oldPremiereIsNotInCinemas() {
        // 42 days before is still in cinemas, 43 days is not.
        let lastDay = makeDetails(releaseDate: "2026-09-25T00:00:00.000Z")
        let tooOld = makeDetails(releaseDate: "2026-09-24T00:00:00.000Z")

        #expect(isInPolishCinemas(lastDay))
        #expect(!isInPolishCinemas(tooOld))
    }

    @Test func futurePremiereIsNotInCinemasYet() {
        let details = makeDetails(releaseDate: "2026-11-07T00:00:00.000Z")

        #expect(!isInPolishCinemas(details))
        #expect(daysSinceReleaseDay("2026-11-07T00:00:00.000Z", today: testToday) == -1)
    }

    @Test func digitalReleaseIsNotCinema() {
        let details = makeDetails(type: 4, releaseDate: "2026-10-17T00:00:00.000Z")

        #expect(!isInPolishCinemas(details))
    }

    @Test func premiereInAnotherCountryDoesNotCount() {
        let details = makeDetails(country: "US", releaseDate: "2026-10-17T00:00:00.000Z")

        #expect(!isInPolishCinemas(details))
    }

    @Test func unreadableDateIsNotInCinemas() {
        let details = makeDetails(releaseDate: "soon")

        #expect(!isInPolishCinemas(details))
        #expect(daysSinceReleaseDay("soon", today: testToday) == -1)
        #expect(daysSinceReleaseDay("2026-10-17T00:00:00.000Z", today: testToday) == 20)
    }
}
