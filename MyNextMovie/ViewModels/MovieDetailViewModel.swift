import Foundation
import Observation

@Observable
final class MovieDetailViewModel {
    private(set) var state: LoadState = .idle
    private(set) var details: MovieDetails = emptyMovieDetails
    private(set) var errorMessage: String = ""

    private let movieId: Int
    private let loadDetails: MovieDetailsLoader

    init(movieId: Int, loadDetails: @escaping MovieDetailsLoader) {
        self.movieId = movieId
        self.loadDetails = loadDetails
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            details = try await loadDetails(movieId)
            state = .loaded
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }
}
