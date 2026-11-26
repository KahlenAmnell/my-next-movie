import MapKit

typealias UserLocationFinder = () async -> UserLocation
typealias LastKnownLocationReader = () -> UserLocation
