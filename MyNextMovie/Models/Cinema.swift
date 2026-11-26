import CoreLocation
import Foundation

/// Distance of a cinema before the app knows where the user is.
nonisolated let unknownDistance: CLLocationDistance = -1

nonisolated let noCinemaSelected = ""
nonisolated let cinemaNotFound = -1
nonisolated let fallbackCoordinate = CLLocationCoordinate2D(
    latitude: 51.1100, longitude: 17.0320)
nonisolated let fallbackUserLocation = UserLocation(
    latitude: fallbackCoordinate.latitude,
    longitude: fallbackCoordinate.longitude,
    isKnown: false)

/// A cinema in Wrocław, a plain struct,
/// so the views and tests do not depend on `MKMapItem`.
nonisolated struct Cinema: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String  // empty when unknown
    let phoneNumber: String  // empty when unknown
    let website: String  // empty when unknown
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    var distanceInMeters = unknownDistance
}

/// Where the user is. `isKnown` is false when the app does not know it.
nonisolated struct UserLocation: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let isKnown: Bool
}

// MARK: - Positions and distances

nonisolated func cinemaCoordinate(_ cinema: Cinema) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: cinema.latitude, longitude: cinema.longitude)
}

nonisolated func userCoordinate(_ location: UserLocation) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
}

nonisolated func distanceInMeters(from user: UserLocation, to cinema: Cinema) -> CLLocationDistance
{
    let userPoint = CLLocation(latitude: user.latitude, longitude: user.longitude)
    let cinemaPoint = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    return userPoint.distance(from: cinemaPoint)
}

nonisolated func isCloser(_ first: Cinema, _ second: Cinema) -> Bool {
    if first.distanceInMeters != second.distanceInMeters {
        return first.distanceInMeters < second.distanceInMeters
    }
    return first.name < second.name
}

nonisolated func cinemasSortedByDistance(
    _ cinemas: [Cinema], from user: UserLocation
) -> [Cinema] {
    var measured = cinemas
    for index in measured.indices {
        measured[index].distanceInMeters = distanceInMeters(from: user, to: measured[index])
    }
    return measured.sorted(by: isCloser)
}

// MARK: - Searching

nonisolated func positionOfCinema(_ cinemas: [Cinema], cinemaId: String) -> Int {
    return cinemas.firstIndex { $0.id == cinemaId } ?? cinemaNotFound
}

nonisolated func containsCinema(_ cinemas: [Cinema], cinemaId: String) -> Bool {
    return positionOfCinema(cinemas, cinemaId: cinemaId) != cinemaNotFound
}

// MARK: - Texts and links

private let metersInKilometer = 1000.0

nonisolated func formattedDistance(_ meters: CLLocationDistance) -> String {
    guard meters != unknownDistance else { return "" }
    let roundedMeters = meters.rounded()
    if roundedMeters < metersInKilometer {
        return "\(Int(roundedMeters)) m"
    }
    return String(format: "%.1f km", meters / metersInKilometer)
}

nonisolated func phoneURL(_ cinema: Cinema) -> URL? {
    let allowed = Set("+0123456789")
    let dialable = cinema.phoneNumber.filter { allowed.contains($0) }
    guard !dialable.isEmpty else { return nil }
    return URL(string: "tel:\(dialable)")
}

nonisolated func hasPhoneNumber(_ cinema: Cinema) -> Bool {
    return phoneURL(cinema) != nil
}

nonisolated func websiteURL(_ cinema: Cinema) -> URL? {
    guard !cinema.website.isEmpty else { return nil }
    return URL(string: cinema.website)
}

nonisolated func hasWebsite(_ cinema: Cinema) -> Bool {
    return websiteURL(cinema) != nil
}
