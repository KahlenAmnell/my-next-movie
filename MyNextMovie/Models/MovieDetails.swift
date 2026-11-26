import Foundation

nonisolated struct MovieDetails: Decodable, Sendable {
    let id: Int
    let tagline: String?
    let runtime: Int?
    let credits: Credits?
    let videos: VideoList?
    let releaseDates: ReleaseDateList?
    let watchProviders: WatchProviderList?
    let recommendations: TMDBMoviePage?

    enum CodingKeys: String, CodingKey {
        case id
        case tagline
        case runtime
        case credits
        case videos
        case releaseDates = "release_dates"
        case watchProviders = "watch/providers"
        case recommendations
    }
}

nonisolated struct Credits: Decodable, Sendable {
    let cast: [CastMember]?
    let crew: [CrewMember]?
}

nonisolated struct CastMember: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
    }
}

nonisolated struct CrewMember: Decodable, Sendable {
    let id: Int
    let name: String
    let job: String?
}

nonisolated struct VideoList: Decodable, Sendable {
    let results: [Video]?
}

nonisolated struct Video: Decodable, Sendable {
    let key: String?
    let site: String?
    let type: String?
    let official: Bool?
}

nonisolated struct ReleaseDateList: Decodable, Sendable {
    let results: [CountryReleaseDates]?
}

nonisolated struct CountryReleaseDates: Decodable, Sendable {
    let countryCode: String
    let releaseDates: [ReleaseDate]?

    enum CodingKeys: String, CodingKey {
        case countryCode = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

nonisolated struct ReleaseDate: Decodable, Sendable {
    let certification: String?
    let releaseDate: String  // "2026-10-17T00:00:00.000Z"
    let type: Int  // 2 and 3 are a cinema premiere

    enum CodingKeys: String, CodingKey {
        case certification
        case releaseDate = "release_date"
        case type
    }
}

let releaseTypeTheatricalLimited = 2
let releaseTypeTheatrical = 3
let typicalCinemaRunInDays = 42

nonisolated struct WatchProviderList: Decodable, Sendable {
    let results: [String: CountryWatchProviders]?
}

nonisolated struct CountryWatchProviders: Decodable, Sendable {
    let link: String?
    let flatrate: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
}

nonisolated struct WatchProvider: Decodable, Identifiable, Sendable {
    let providerId: Int
    let providerName: String
    let logoPath: String?

    var id: Int { providerId }

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
}

// MARK: - Constants and Helpers

let emptyMovieDetails = MovieDetails(
    id: 0,
    tagline: nil,
    runtime: nil,
    credits: nil,
    videos: nil,
    releaseDates: nil,
    watchProviders: nil,
    recommendations: nil
)

let noWatchProviders = CountryWatchProviders(
    link: nil,
    flatrate: nil,
    rent: nil,
    buy: nil
)

var watchRegionCode: String {
    Locale.current.region?.identifier ?? "PL"
}

func formattedRuntime(_ details: MovieDetails) -> String {
    guard let runtime = details.runtime, runtime > 0 else {
        return ""
    }
    let hours = runtime / 60
    let minutes = runtime % 60
    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h 0m"
    } else {
        return "\(minutes)m"
    }
}

func directorNames(_ details: MovieDetails) -> String {
    guard let crew = details.credits?.crew else { return "" }
    let directors = crew.filter { $0.job == "Director" }.map { $0.name }
    let uniqueDirectors = Array(Set(directors))
    return uniqueDirectors.joined(separator: ", ")
}

func ageCertification(_ details: MovieDetails, regionCode: String) -> String {
    guard let results = details.releaseDates?.results else { return "" }
    if let countryRelease = results.first(where: { $0.countryCode == regionCode }),

        let dates = countryRelease.releaseDates {

        for date in dates {
            if let cert = date.certification, !cert.isEmpty {
                return cert
            }
        }
    }
    return ""
}

func trailerKey(_ details: MovieDetails) -> String {
    guard let videos = details.videos?.results else { return "" }
    let youtubeVideos = videos.filter { $0.site == "YouTube" && $0.type == "Trailer" }

    if let official = youtubeVideos.first(where: { $0.official == true }), let key = official.key {
        return key
    }
    if let first = youtubeVideos.first, let key = first.key {
        return key
    }
    return ""
}

func trailerURL(_ details: MovieDetails) -> URL? {
    let key = trailerKey(details)
    guard !key.isEmpty else { return nil }
    return URL(string: "https://www.youtube.com/watch?v=\(key)")
}

func hasTrailer(_ details: MovieDetails) -> Bool {
    !trailerKey(details).isEmpty
}

func movieFactsLine(_ movie: Movie, _ details: MovieDetails, regionCode: String) -> String {
    var components: [String] = []

    if movie.releaseDate.count >= 4 {
        let year = String(movie.releaseDate.prefix(4))
        components.append(year)
    }
    let rating = movie.voteAverage
    if rating > 0 {
        let formattedRating = String(format: "★ %.1f", rating)
        components.append(formattedRating)
    }

    let runtimeStr = formattedRuntime(details)
    if !runtimeStr.isEmpty {
        components.append(runtimeStr)
    }

    let certStr = ageCertification(details, regionCode: regionCode)
    if !certStr.isEmpty {
        components.append(certStr)
    }

    return components.joined(separator: " · ")
}

func watchProviders(_ details: MovieDetails, regionCode: String) -> CountryWatchProviders {
    guard let providersResults = details.watchProviders?.results,
          let countryProviders = providersResults[regionCode] else {
        return noWatchProviders
    }
    return countryProviders
}

func hasWatchProviders(_ countryProviders: CountryWatchProviders) -> Bool {
    let flatrate = countryProviders.flatrate ?? []
    let rent = countryProviders.rent ?? []
    let buy = countryProviders.buy ?? []
    return !flatrate.isEmpty || !rent.isEmpty || !buy.isEmpty
}

func profileURL(_ castMember: CastMember) -> URL? {
    guard let path = castMember.profilePath, !path.isEmpty else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
}

func logoURL(_ provider: WatchProvider) -> URL? {
    guard let path = provider.logoPath, !path.isEmpty else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/w92\(path)")
}

// MARK: - Now in cinemas

func isInCinemas(_ details: MovieDetails, regionCode: String, today: Date) -> Bool {
    let countries = details.releaseDates?.results ?? []
    let country = countries.first { $0.countryCode == regionCode }
    let releases = country?.releaseDates ?? []
    return releases.contains { isRecentCinemaPremiere($0, today: today) }
}

func daysSinceReleaseDay(_ releaseDate: String, today: Date) -> Int {
    let day = String(releaseDate.prefix(dayTextLength))
    let format = Date.ISO8601FormatStyle().year().month().day()
    guard let premiere = try? Date(day, strategy: format) else { return -1 }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let days = calendar.dateComponents([.day], from: premiere, to: calendar.startOfDay(for: today))
    return max(days.day ?? -1, -1)
}

private let dayTextLength = 10

private func isRecentCinemaPremiere(_ release: ReleaseDate, today: Date) -> Bool {
    let isCinemaType =
        release.type == releaseTypeTheatricalLimited || release.type == releaseTypeTheatrical
    let daysAgo = daysSinceReleaseDay(release.releaseDate, today: today)
    return isCinemaType && daysAgo >= 0 && daysAgo <= typicalCinemaRunInDays
}
