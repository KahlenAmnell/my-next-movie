import Foundation

nonisolated struct CloudSavedMovie: Codable, Equatable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String
    let posterPath: String?
    let voteAverage: Double
    let genreIds: [Int]
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
        case savedAt = "saved_at"
    }
}
