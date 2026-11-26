import Testing

@testable import MyNextMovie

private let testYear = 2026

private let keanuFilters = MovieFilters(
    genreIds: [genreIdComedy], fromYear: 1990, toYear: 1999,
    people: ["Keanu Reeves"], keywords: [], title: "")

private let matrix = Movie(
    id: 603, title: "The Matrix", overview: "", releaseDate: "1999-03-31",
    posterPath: nil, voteAverage: 8.2, genreIds: [genreIdAction])

@MainActor
private final class SearchRecorder {
    var wishes: [String] = []
    var filterSearches: [MovieFilters] = []
    var textSearches: [String] = []
    var textSearchGenreIds: [Int] = []
}

@MainActor
private func makeViewModel(
    _ recorder: SearchRecorder,
    parse: @escaping (String) async throws -> MovieFilters,
    byFilters: @escaping (MovieFilters) async throws -> [Movie] = { _ in [matrix] }
) -> WishSearchViewModel {
    return WishSearchViewModel(
        parseWish: { wish in
            recorder.wishes.append(wish)
            return try await parse(wish)
        },
        searchByFilters: { filters in
            recorder.filterSearches.append(filters)
            return try await byFilters(filters)
        },
        searchByText: { query, genreId in
            recorder.textSearches.append(query)
            recorder.textSearchGenreIds.append(genreId)
            return [matrix]
        },
        currentYear: testYear
    )
}

@MainActor
private final class ModelSwitch {
    var works = false

    func answer(_ wish: String) async throws -> MovieFilters {
        if works {
            return keanuFilters
        }
        throw NoConnection()
    }
}

@MainActor
struct WishSearchViewModelTests {
    @Test func searchesWithTheFiltersOfTheModel() async {
        let recorder = SearchRecorder()
        let viewModel = makeViewModel(recorder, parse: { _ in keanuFilters })
        viewModel.wish = "  something light with Keanu from the 90s \n"

        await viewModel.search()

        #expect(recorder.wishes == ["something light with Keanu from the 90s"])
        #expect(recorder.filterSearches == [keanuFilters])
        #expect(recorder.textSearches.isEmpty)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.movies == [matrix])
        #expect(viewModel.filters == keanuFilters)
        #expect(!viewModel.isPlainSearch)
    }

    @Test func checksTheModelAnswerBeforeSearching() async {
        let recorder = SearchRecorder()
        let wrongAnswer = MovieFilters(
            genreIds: [9999, genreIdComedy], fromYear: 1999, toYear: 1990,
            people: [" Keanu Reeves ", ""], keywords: [], title: "")
        let viewModel = makeViewModel(recorder, parse: { _ in wrongAnswer })
        viewModel.wish = "anything"

        await viewModel.search()

        let expected = validatedFilters(wrongAnswer, currentYear: testYear)
        #expect(recorder.filterSearches == [expected])
        #expect(expected.genreIds == [genreIdComedy])
        #expect(expected.fromYear == 1990)
    }

    @Test func fallsBackToTextSearchWhenTheModelFails() async {
        let recorder = SearchRecorder()
        let viewModel = makeViewModel(recorder, parse: { _ in throw NoConnection() })
        viewModel.wish = "matrix"

        await viewModel.search()

        #expect(recorder.filterSearches.isEmpty)
        #expect(recorder.textSearches == ["matrix"])
        #expect(recorder.textSearchGenreIds == [noGenreId])
        #expect(viewModel.isPlainSearch)
        #expect(viewModel.plainSearchReason == "No connection")
        #expect(viewModel.state == .loaded)
        #expect(viewModel.movies == [matrix])
    }

    @Test func fallsBackToTextSearchWithoutFilters() async {
        let recorder = SearchRecorder()
        let viewModel = makeViewModel(recorder, parse: { _ in noMovieFilters })
        viewModel.wish = "matrix"

        await viewModel.search()

        #expect(recorder.filterSearches.isEmpty)
        #expect(recorder.textSearches == ["matrix"])
        #expect(viewModel.isPlainSearch)
        #expect(viewModel.state == .loaded)
    }

    @Test func showsErrorWhenTheMovieSearchFails() async {
        let recorder = SearchRecorder()
        let viewModel = makeViewModel(
            recorder, parse: { _ in keanuFilters }, byFilters: { _ in throw NoConnection() })
        viewModel.wish = "Keanu"

        await viewModel.search()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
    }

    @Test func emptyWishDoesNothing() async {
        let recorder = SearchRecorder()
        let viewModel = makeViewModel(recorder, parse: { _ in keanuFilters })
        viewModel.wish = "  \n  "

        await viewModel.search()

        #expect(recorder.wishes.isEmpty)
        #expect(viewModel.state == .idle)
        #expect(!viewModel.canSearch)
    }

    @Test func nextSearchForgetsThePlainSearchReason() async {
        let recorder = SearchRecorder()
        let model = ModelSwitch()
        let viewModel = makeViewModel(recorder, parse: model.answer)
        viewModel.wish = "Keanu"

        await viewModel.search()
        #expect(viewModel.isPlainSearch)

        model.works = true
        await viewModel.search()
        #expect(!viewModel.isPlainSearch)
        #expect(viewModel.plainSearchReason.isEmpty)
    }
}

@MainActor
struct WishLengthTests {
    @Test func longWishIsCutToTwoHundredCharacters() {
        let longWish = String(repeating: "a", count: maxWishLength + 50)

        #expect(wishLimitedToMaxLength(longWish).count == maxWishLength)
        #expect(wishLimitedToMaxLength("short") == "short")
    }
}
