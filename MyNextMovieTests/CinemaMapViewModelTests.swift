import Foundation
import MapKit
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

private let walkingRoute = CinemaRoute(
    travelTimeInSeconds: 720, distanceInMeters: 950, line: MKPolyline())
private let drivingRoute = CinemaRoute(
    travelTimeInSeconds: 300, distanceInMeters: 1400, line: MKPolyline())

@MainActor
private func makeDetailViewModel(
    userLocation: UserLocation = testUserLocation,
    findRoute: @escaping CinemaRouteFinder
) -> CinemaDetailViewModel {
    return CinemaDetailViewModel(
        cinema: testCinemaDCF, userLocation: userLocation, findRoute: findRoute)
}

@MainActor
struct CinemaDetailViewModelTests {
    @Test func findsNoRouteWithoutLocation() async {
        let viewModel = makeDetailViewModel(userLocation: fallbackUserLocation) { _, _, _ in
            Issue.record("The route must not be requested without a location.")
            return walkingRoute
        }

        await viewModel.loadRoute()

        #expect(!viewModel.canFindRoute)
        #expect(viewModel.routeState == .idle)
    }

    @Test func findsRouteForSelectedTravelMode() async {
        let viewModel = makeDetailViewModel { _, _, mode in
            mode == .walking ? walkingRoute : drivingRoute
        }

        await viewModel.loadRoute()
        #expect(viewModel.routeState == .loaded)
        #expect(viewModel.route.travelTimeInSeconds == 720)

        viewModel.travelMode = .driving
        await viewModel.loadRoute()
        #expect(viewModel.route.travelTimeInSeconds == 300)
    }

    @Test func showsErrorWhenRouteFails() async {
        let viewModel = makeDetailViewModel { _, _, _ in throw NoRouteFound() }

        await viewModel.loadRoute()

        #expect(viewModel.routeState == .failed)
        #expect(viewModel.errorMessage == "Maps found no way to this cinema.")
    }

    @Test func routeSummaryHasTimeAndDistance() {
        let viewModel = makeDetailViewModel { _, _, _ in walkingRoute }

        #expect(viewModel.formattedTravelTime(720) == "12 min")
        #expect(viewModel.routeSummary(walkingRoute) == "12 min \u{00B7} 950 m")
    }
}
