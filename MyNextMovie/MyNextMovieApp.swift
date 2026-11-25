import SwiftData
import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: storedModelTypes)
    }
}

/// Connects the screens to the database: the screens get loaders that already know the context.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) { moviesScreen }
            Tab("Saved", systemImage: symbolNameSaved) { savedScreen }
            Tab("Search", systemImage: symbolNameSearch, role: .search) { searchScreen }
        }
    }

    private var moviesScreen: some View {
        MovieListView(
            viewModel: MovieListViewModel(loadMovies: loadPopularMoviesWithCache),
            loadDetails: loadDetailsWithCache
        )
    }

    private var savedScreen: some View {
        SavedMoviesView(loadDetails: loadDetailsWithCache)
    }

    private var searchScreen: some View {
        SearchView(
            viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
            loadDetails: loadDetailsWithCache
        )
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}
