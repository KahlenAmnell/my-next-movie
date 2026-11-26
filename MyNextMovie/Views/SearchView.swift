import SwiftData
import SwiftUI

private let searchDelayAfterTyping = Duration.milliseconds(300)

private let searchInputKeySeparator = "|"

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SearchViewModel
    @State private var wishViewModel: WishSearchViewModel
    @State private var isShowingAIResults = false
    private let loadDetails: MovieDetailsLoader

    init(
        viewModel: SearchViewModel,
        wishViewModel: WishSearchViewModel,
        loadDetails: @escaping MovieDetailsLoader
    ) {
        _viewModel = State(initialValue: viewModel)
        _wishViewModel = State(initialValue: wishViewModel)
        self.loadDetails = loadDetails
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                genreFilter
                askAISection
                content.frame(maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Title or keyword")
            .onSubmit(of: .search) {
                recordCurrentSearch()
                askAI()
            }
            .onChange(of: viewModel.query) {
                isShowingAIResults = false
            }
            .onChange(of: viewModel.selectedGenreId) {
                isShowingAIResults = false
            }
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie, loadDetails: loadDetails)
            }
            .task(id: searchInputKey(viewModel.query, viewModel.selectedGenreId)) {
                await searchAfterPause()
            }
        }
    }

    private var genreFilter: some View {
        GenreFilter(selectedGenreId: viewModel.selectedGenreId, toggleGenre: viewModel.toggleGenre)
    }

    private var hasQuery: Bool {
        return !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The "Ask AI" button, or the grey line with what the AI understood.
    @ViewBuilder
    private var askAISection: some View {
        if isShowingAIResults {
            Text(wishInfoLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, spacingSmall)
        } else if hasQuery {
            Button(action: askAI) {
                Label("Ask AI", systemImage: symbolNameWish)
            }
            .buttonStyle(.bordered)
            .padding(.vertical, spacingSmall)
        }
    }

    private var wishInfoLine: String {
        if wishViewModel.isPlainSearch {
            return wishViewModel.plainSearchReason
        }
        return filtersSummary(wishViewModel.filters)
    }

    @ViewBuilder
    private var content: some View {
        if isShowingAIResults {
            wishContent
        } else {
            searchContent
        }
    }

    @ViewBuilder
    private var wishContent: some View {
        switch wishViewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            SearchResults(movies: wishViewModel.movies, query: wishViewModel.wish)
        case .failed:
            ErrorView(title: "Search failed", message: wishViewModel.errorMessage) {
                Task { await wishViewModel.search() }
            }
        }
    }

    private func askAI() {
        if !hasQuery {
            return
        }
        wishViewModel.wish = wishLimitedToMaxLength(viewModel.query)
        isShowingAIResults = true
        Task { await wishViewModel.search() }
    }

    @ViewBuilder
    private var searchContent: some View {
        switch viewModel.state {
        case .idle:
            SearchStartView(selectQuery: selectQuery)
        case .loading:
            ProgressView()
        case .loaded:
            SearchResults(movies: viewModel.movies, query: viewModel.query)
        case .failed:
            ErrorView(title: "Search failed", message: viewModel.errorMessage) {
                Task { await viewModel.search() }
            }
        }
    }

    private func recordCurrentSearch() {
        recordSearch(modelContext, query: viewModel.query, now: .now)
    }

    private func selectQuery(_ text: String) {
        viewModel.query = text
        recordSearch(modelContext, query: text, now: .now)
    }

    private func searchAfterPause() async {
        try? await Task.sleep(for: searchDelayAfterTyping)
        if Task.isCancelled {
            return
        }
        await viewModel.search()
    }
}

private func searchInputKey(_ query: String, _ selectedGenreId: Int) -> String {
    return String(selectedGenreId) + searchInputKeySeparator + query
}

private struct SearchStartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SearchHistoryEntry.searchedAt, order: .reverse)
    private var history: [SearchHistoryEntry]
    private let selectQuery: (String) -> Void

    init(selectQuery: @escaping (String) -> Void) {
        self.selectQuery = selectQuery
    }

    @ViewBuilder
    var body: some View {
        if history.isEmpty {
            ContentUnavailableView(
                "Find a movie",
                systemImage: symbolNameSearch,
                description: Text("Search by title or keyword, or pick a genre.")
            )
        } else {
            historyList
        }
    }

    private var historyList: some View {
        List {
            Section {
                ForEach(history, content: historyRow)
            } header: {
                historyHeader
            }
        }
        .listStyle(.plain)
    }

    private var historyHeader: some View {
        HStack {
            Text("Recent Searches")
            Spacer()
            Button("Clear") { clearSearchHistory(modelContext) }
        }
    }

    private func historyRow(_ entry: SearchHistoryEntry) -> some View {
        Button {
            selectQuery(entry.query)
        } label: {
            Label(entry.query, systemImage: symbolNameSearchHistory)
        }
        .foregroundStyle(.primary)
    }
}

private struct GenreFilter: View {
    let selectedGenreId: Int
    let toggleGenre: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacingSmall) {
                ForEach(genreTable) {
                    genre in genreFilterChip(genre.id)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, spacingSmall)
        }
    }
    
    private func genreFilterChip(_ genreId: Int) -> some View {
        Button {
            toggleGenre(genreId)
        } label: {
            GenreChip(genreId: genreId, isSelected: genreId == selectedGenreId)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchView(
        viewModel: SearchViewModel(searchMovies: searchSampleMovies),
        wishViewModel: WishSearchViewModel(
            parseWish: { _ in noMovieFilters },
            searchByFilters: { _ in sampleMovies },
            searchByText: searchSampleMovies),
        loadDetails: loadSampleMovieDetails
    )
    .modelContainer(for: storedModelTypes, inMemory: true)
}
