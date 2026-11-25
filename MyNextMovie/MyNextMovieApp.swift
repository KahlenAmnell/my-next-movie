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

private struct RootView: View {
    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                MovieListView(viewModel: MovieListViewModel(loadMovies: {
                    try await fetchPopularMovies()
                }))
            }

            Tab("Saved", systemImage: symbolNameSaved) {
                SavedMoviesView(loadDetails: { movieId in
                    try await fetchMovieDetails(movieId: movieId)
                })
            }

            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                SearchView(viewModel: SearchViewModel(searchMovies: { query, genreId in
                    try await searchTMDBMovies(query: query, genreId: genreId)
                }))
            }
        }
    }
}
