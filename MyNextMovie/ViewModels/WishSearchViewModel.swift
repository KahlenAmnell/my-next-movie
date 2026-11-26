import Foundation
import Observation

let maxWishLength = 200
let noFiltersReason = "The AI found nothing to filter by, so this is a search by title."

func wishLimitedToMaxLength(_ wish: String) -> String {
    return String(String.UnicodeScalarView(wish.unicodeScalars.prefix(maxWishLength)))
}

@Observable
final class WishSearchViewModel {
    var wish = ""
    private(set) var state = LoadState.idle
    private(set) var movies: [Movie] = []
    private(set) var errorMessage = ""
    private(set) var filters = noMovieFilters
    private(set) var plainSearchReason = ""

    private let parseWish: MovieWishParser
    private let searchByFilters: FilteredMovieSearch
    private let searchByText: MovieSearch
    private let currentYear: Int

    init(
        parseWish: @escaping MovieWishParser,
        searchByFilters: @escaping FilteredMovieSearch,
        searchByText: @escaping MovieSearch,
        currentYear: Int = yearOfToday()
    ) {
        self.parseWish = parseWish
        self.searchByFilters = searchByFilters
        self.searchByText = searchByText
        self.currentYear = currentYear
    }

    var isPlainSearch: Bool {
        return !plainSearchReason.isEmpty
    }

    var canSearch: Bool {
        return !trimmedWish.isEmpty && state != .loading
    }

    private var trimmedWish: String {
        return wish.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func search() async {
        let sentence = trimmedWish
        if sentence.isEmpty {
            return
        }
        state = .loading
        plainSearchReason = ""
        filters = await filtersOfTheModel(for: sentence)
        do {
            if isPlainSearch {
                movies = try await searchByText(sentence, noGenreId)
            } else {
                movies = try await searchByFilters(filters)
            }
            state = .loaded
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    private func filtersOfTheModel(for sentence: String) async -> MovieFilters {
        do {
            let answer = try await parseWish(sentence)
            let checked = validatedFilters(answer, currentYear: currentYear)
            if !hasAnyFilter(checked) {
                plainSearchReason = noFiltersReason
            }
            return checked
        } catch {
            plainSearchReason = error.localizedDescription
            return noMovieFilters
        }
    }
}
