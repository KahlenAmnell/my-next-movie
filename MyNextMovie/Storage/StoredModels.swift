import Foundation
import SwiftData

@Model
final class SavedMovie {
    @Attribute(.unique) var movieId: Int
    var title: String
    var overview: String?
    var releaseDate: String
    var posterPath: String?
    var voteAverage: Double
    var genreIds: [Int]
    var savedAt: Date
    var isInCloud: Bool = false

    init(movie: Movie, savedAt: Date) {
        self.movieId = movie.id
        self.title = movie.title
        self.overview = movie.overview
        self.releaseDate = movie.releaseDate
        self.posterPath = movie.posterPath
        self.voteAverage = movie.voteAverage
        self.genreIds = movie.genreIds
        self.savedAt = savedAt
    }
}

let storedModelTypes: [any PersistentModel.Type] = [SavedMovie.self]
