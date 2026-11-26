import MapKit
import Observation

@Observable
final class CinemaMapViewModel {
    private(set) var cinemas: [Cinema]
    private(set) var userLocation = fallbackUserLocation
    var selectedCinemaId = noCinemaSelected
    var visibleRegion = wroclawMapRegion

    private let allCinemas: [Cinema]
    private let findUserLocation: UserLocationFinder
    private let lastKnownLocation: LastKnownLocationReader
    private var hasStartedLocating = false
    private var hasAskedForLocation = false

    init(
        cinemas: [Cinema],
        findUserLocation: @escaping UserLocationFinder,
        lastKnownLocation: @escaping LastKnownLocationReader = { fallbackUserLocation }
    ) {
        self.cinemas = cinemasSortedByName(cinemas)
        self.findUserLocation = findUserLocation
        self.lastKnownLocation = lastKnownLocation
        self.allCinemas = cinemas
    }

    var isLocationUnavailable: Bool {
        return hasAskedForLocation && !userLocation.isKnown
    }

    func locateUser() async {
        use(lastKnownLocation())
        use(await findUserLocation())
        hasAskedForLocation = true
    }

    func locateUserIfNeeded() async {
        if hasStartedLocating {
            return
        }
        hasStartedLocating = true
        await locateUser()
    }

    func toggleCinema(_ cinema: Cinema) {
        selectedCinemaId = selectedCinemaId == cinema.id ? noCinemaSelected : cinema.id
    }

    private func use(_ location: UserLocation) {
        guard location.isKnown else { return }
        userLocation = location
        cinemas = cinemasSortedByDistance(allCinemas, from: location)
    }
}

private func cinemasSortedByName(_ cinemas: [Cinema]) -> [Cinema] {
    return cinemas.sorted { $0.name < $1.name }
}
