import MapKit

typealias UserLocationFinder = () async -> UserLocation
typealias LastKnownLocationReader = () -> UserLocation

enum TravelMode {
    case walking
    case driving
}

struct CinemaRoute {
    let travelTimeInSeconds: TimeInterval
    let distanceInMeters: CLLocationDistance
    let line: MKPolyline
}

let noRoute = CinemaRoute(travelTimeInSeconds: 0, distanceInMeters: 0, line: MKPolyline())

typealias CinemaRouteFinder = (UserLocation, Cinema, TravelMode) async throws -> CinemaRoute

struct NoRouteFound: LocalizedError {
    var errorDescription: String? { "Maps found no way to this cinema." }
}

// MARK: - MapKit

func findMapKitRoute(
    userLocation: UserLocation, cinema: Cinema, travelMode: TravelMode
) async throws -> CinemaRoute {
    let request = MKDirections.Request()
    request.source = mapItem(at: userCoordinate(userLocation))
    request.destination = mapItemForCinema(cinema)
    request.transportType = transportTypeForMapKit(travelMode)
    let response = try await MKDirections(request: request).calculate()
    guard let route = response.routes.first else { throw NoRouteFound() }
    return CinemaRoute(
        travelTimeInSeconds: route.expectedTravelTime,
        distanceInMeters: route.distance,
        line: route.polyline)
}

func mapItemForCinema(_ cinema: Cinema) -> MKMapItem {
    let item = mapItem(at: cinemaCoordinate(cinema))
    item.name = cinema.name
    return item
}

func transportTypeForMapKit(_ travelMode: TravelMode) -> MKDirectionsTransportType {
    switch travelMode {
    case .walking: return .walking
    case .driving: return .automobile
    }
}

func openCinemaInMaps(_ cinema: Cinema, travelMode: TravelMode) {
    let launchOptions = [MKLaunchOptionsDirectionsModeKey: launchDirectionsMode(travelMode)]
    mapItemForCinema(cinema).openInMaps(launchOptions: launchOptions)
}

func findLookAroundScene(_ cinema: Cinema) async -> MKLookAroundScene? {
    let request = MKLookAroundSceneRequest(coordinate: cinemaCoordinate(cinema))
    return try? await request.scene
}

private func mapItem(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
    return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
}

private func launchDirectionsMode(_ travelMode: TravelMode) -> String {
    switch travelMode {
    case .walking: return MKLaunchOptionsDirectionsModeWalking
    case .driving: return MKLaunchOptionsDirectionsModeDriving
    }
}
