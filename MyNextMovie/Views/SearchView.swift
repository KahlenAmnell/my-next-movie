import SwiftData
import SwiftUI

private let searchDelayAfterTyping = Duration.milliseconds(300)

private let searchResultThumbnailWidth: CGFloat = 56
private let searchResultTitleMaxLines = 2
private let searchInputKeySeparator = "|"

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                genreFilter
                content.frame(maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Title or keyword")
            .onSubmit(of: .search) { recordCurrentSearch() }
            .navigationDestination(for: Movie.self) { movie in MovieDetailView(movie: movie) }
            .task(id: searchInputKey(viewModel.query, viewModel.selectedGenreId)) {
                await searchAfterPause()
            }
        }
    }

    private var genreFilter: some View {
        GenreFilter(selectedGenreId: viewModel.selectedGenreId, toggleGenre: viewModel.toggleGenre)
    }

    @ViewBuilder
    private var content: some View {
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
    let selectQuery: (String) -> Void

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
                ForEach(history) { entry in
                    historyRow(entry)
                }
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

private struct SearchResults: View {
    let movies: [Movie]
    let query: String
    
    @ViewBuilder
    var body: some View {
        if movies.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(movies) { movie in
                SearchResultRow(movie: movie)
            }
            .listStyle(.plain)
        }
    }
}

private struct SearchResultRow: View {
    let movie: Movie
    
    var body: some View {
        NavigationLink(value: movie) {
            HStack(spacing: spacingMedium) {
                PosterView(movie: movie, cornerRadius: thumbnailCornerRadius).frame(width: searchResultThumbnailWidth)
                VStack(alignment: .leading, spacing: spacingExtraSmall) {
                    Text(movie.title).font(.headline).lineLimit(searchResultTitleMaxLines)
                    Text(movieSubtitle(movie)).font(.subheadline).foregroundColor(.secondary)
                    Text(ratingWithStar(movie)).font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, spacingExtraSmall)
        }
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel(searchMovies: searchSampleMovies))
        .modelContainer(for: storedModelTypes, inMemory: true)
}
