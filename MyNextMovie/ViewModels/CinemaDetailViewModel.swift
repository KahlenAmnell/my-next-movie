import Foundation
import Observation

private let secondsInMinute = 60.0
private let summarySeparator = " \u{00B7} "

@Observable
final class CinemaDetailViewModel {
    let cinema: Cinema
    let userLocation: UserLocation
    var travelMode = TravelMode.walking
    private(set) var route = noRoute
    private(set) var routeState = LoadState.idle
    private(set) var errorMessage = ""

    private let findRoute: CinemaRouteFinder

    init(cinema: Cinema, userLocation: UserLocation, findRoute: @escaping CinemaRouteFinder) {
        self.cinema = cinema
        self.userLocation = userLocation
        self.findRoute = findRoute
    }

    var canFindRoute: Bool {
        return userLocation.isKnown
    }

    func loadRoute() async {
        guard canFindRoute else { return }
        let requestedMode = travelMode
        routeState = .loading
        do {
            let foundRoute = try await findRoute(userLocation, cinema, requestedMode)
            guard requestedMode == travelMode else { return }
            route = foundRoute
            routeState = .loaded
        } catch {
            guard requestedMode == travelMode else { return }
            errorMessage = error.localizedDescription
            routeState = .failed
        }
    }

    func formattedTravelTime(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / secondsInMinute).rounded())
        return "\(minutes) min"
    }

    func routeSummary(_ route: CinemaRoute) -> String {
        let time = formattedTravelTime(route.travelTimeInSeconds)
        return time + summarySeparator + formattedDistance(route.distanceInMeters)
    }
}
