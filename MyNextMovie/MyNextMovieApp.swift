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
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var accountViewModel: AccountViewModel?

    var body: some View {
        if let accountViewModel {
            AppTabs(
                viewModel: accountViewModel,
                loadMovies: loadPopularMoviesWithCache,
                searchMovies: searchTMDBMovies,
                loadDetails: loadDetailsWithCache
            )
        } else {
            Color.clear.onAppear { accountViewModel = makeAccountViewModel() }
        }
    }

    private func makeAccountViewModel() -> AccountViewModel {
        return AccountViewModel(
            account: supabaseAccountService,
            syncSavedMovies: syncWithAccount,
            clearSavedMovies: clearDevice
        )
    }

    private func syncWithAccount() async throws {
        try await syncSavedMovies(modelContext, cloud: supabaseSavedMoviesCloud)
    }

    private func clearDevice() {
        clearSavedMovies(modelContext)
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}

private struct AppTabs: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: AccountViewModel
    @Query(filter: #Predicate<SavedMovie> { savedMovie in savedMovie.isInCloud == false })
    private var unsentMovies: [SavedMovie]
    @Query private var removedMovies: [RemovedSavedMovie]

    let loadMovies: MovieLoader
    let searchMovies: MovieSearch
    let loadDetails: MovieDetailsLoader

    private var unsentChangeCount: Int {
        return unsentMovies.count + removedMovies.count
    }

    var body: some View {
        content
            .task { await viewModel.syncSavedMovies() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    syncNow()
                }
            }
            .onChange(of: unsentChangeCount) { oldCount, newCount in
                // A drop is the result of a sync, so it needs no further sync.
                if newCount > oldCount {
                    syncNow()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSignedIn {
            TabView {
                Tab("Movies", systemImage: symbolNameMovies) { moviesScreen }
                Tab("Saved", systemImage: symbolNameSaved) { savedScreen }
                Tab("Cinemas", systemImage: symbolNameCinema) { cinemaMap }
                Tab("Account", systemImage: symbolNameAccount) {
                    AccountView(viewModel: viewModel)
                }
                Tab("Search", systemImage: symbolNameSearch, role: .search) { searchScreen }
            }
        } else {
            SignInView(viewModel: viewModel)
        }
    }

    private var moviesScreen: some View {
        MovieListView(
            viewModel: MovieListViewModel(loadMovies: loadMovies),
            loadDetails: loadDetails
        )
    }

    private var savedScreen: some View {
        SavedMoviesView(loadDetails: loadDetails)
    }

    private var cinemaMap: some View {
        cinemaMapView(placement: .tab)
    }

    private var searchScreen: some View {
        let wishViewModel = WishSearchViewModel(
            parseWish: parseWishWithAI,
            searchByFilters: searchTMDBMoviesByFilters,
            searchByText: searchTMDBMovies)
        return SearchView(
            viewModel: SearchViewModel(searchMovies: searchMovies),
            wishViewModel: wishViewModel,
            loadDetails: loadDetails
        )
    }

    private func syncNow() {
        Task { await viewModel.syncSavedMovies() }
    }
}
