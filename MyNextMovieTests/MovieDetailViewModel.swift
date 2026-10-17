import XCTest
@testable import MyNextMovie

@MainActor
final class MovieDetailViewModelTests: XCTestCase {

    struct MockError: Error {
        var localizedDescription: String { "No connection" }
    }

    func testStartsIdleWithEmptyDetails() {
        let vm = MovieDetailViewModel(movieId: 123) { _ in emptyMovieDetails }
        XCTAssertEqual(vm.state, .idle)
        XCTAssertNil(vm.details.credits?.cast)
    }

    func testLoadsDetailsOfItsMovie() async {
        let expectedId = 456
        let vm = MovieDetailViewModel(movieId: expectedId) { id in
            XCTAssertEqual(id, expectedId)
            return MovieDetails(id: id, tagline: "Tag", runtime: 100, credits: nil, videos: nil, releaseDates: nil, watchProviders: nil, recommendations: nil)
        }

        await vm.load()
        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.details.id, expectedId)
        XCTAssertEqual(vm.details.tagline, "Tag")
    }

    func testShowsErrorWhenLoadingFails() async {
        let vm = MovieDetailViewModel(movieId: 789) { _ in
            throw MockError()
        }

        await vm.load()
        XCTAssertEqual(vm.state, .failed)
        XCTAssertEqual(vm.errorMessage, "No connection")
    }

    func testLoadIfNeededLoadsOnlyOnce() async {
        var callCount = 0
        let vm = MovieDetailViewModel(movieId: 100) { id in
            callCount += 1
            return emptyMovieDetails
        }

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()

        XCTAssertEqual(callCount, 1)
    }
}
