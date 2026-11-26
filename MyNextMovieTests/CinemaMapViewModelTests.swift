import Foundation
import Testing

@testable import MyNextMovie

@MainActor
private final class LocationAsks {
    private(set) var count = 0

    func answer(with location: UserLocation) -> UserLocation {
        count += 1
        return location
    }
}

private let userNearHelios = UserLocation(latitude: 51.1188, longitude: 16.9906, isKnown: true)

@MainActor
private func makeViewModel(
    fresh: UserLocation = fallbackUserLocation,
    lastKnown: UserLocation = fallbackUserLocation
) -> CinemaMapViewModel {
    return CinemaMapViewModel(
        cinemas: testCinemas,
        findUserLocation: { fresh },
        lastKnownLocation: { lastKnown })
}

@MainActor
struct CinemaMapViewModelTests {
    @Test func showsCinemasAtOnceByName() {
        let viewModel = makeViewModel()

        #expect(
            namesOf(viewModel.cinemas) == [
                "DCF", "Helios Magnolia", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki",
            ])
    }

    @Test func sortsByDistanceOnceUserIsFound() async {
        let viewModel = makeViewModel(fresh: testUserLocation)

        await viewModel.locateUser()

        #expect(viewModel.cinemas.first?.name == "DCF")
        #expect(viewModel.cinemas.first?.distanceInMeters != unknownDistance)
    }

    @Test func lastKnownLocationIsUsedWhenNoFreshOneComes() async {
        let viewModel = makeViewModel(fresh: fallbackUserLocation, lastKnown: testUserLocation)

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.name == "DCF")
        #expect(!viewModel.isLocationUnavailable)
    }

    @Test func freshLocationReplacesLastKnownOne() async {
        let viewModel = makeViewModel(fresh: userNearHelios, lastKnown: testUserLocation)

        await viewModel.locateUser()

        #expect(viewModel.userLocation == userNearHelios)
        #expect(viewModel.cinemas.first?.name == "Helios Magnolia")
    }

    @Test func saysWhenLocationIsUnavailable() async {
        let viewModel = makeViewModel()
        #expect(!viewModel.isLocationUnavailable)

        await viewModel.locateUser()

        #expect(viewModel.isLocationUnavailable)
    }

    @Test func asksForLocationOnlyOnce() async {
        let asks = LocationAsks()
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { asks.answer(with: testUserLocation) })

        await viewModel.locateUserIfNeeded()
        await viewModel.locateUserIfNeeded()

        #expect(asks.count == 1)
    }

    @Test func togglesSelection() {
        let viewModel = makeViewModel()
        #expect(viewModel.selectedCinemaId == noCinemaSelected)

        viewModel.toggleCinema(testCinemaDCF)
        #expect(viewModel.selectedCinemaId == testCinemaDCF.id)

        viewModel.toggleCinema(testCinemaHelios)
        #expect(viewModel.selectedCinemaId == testCinemaHelios.id)

        viewModel.toggleCinema(testCinemaHelios)
        #expect(viewModel.selectedCinemaId == noCinemaSelected)
    }
}
