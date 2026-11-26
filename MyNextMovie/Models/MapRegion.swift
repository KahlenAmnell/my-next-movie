import MapKit

let wroclawMapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(
        latitude: 51.0956, longitude: 17.0230),
    latitudinalMeters: 15500,
    longitudinalMeters: 14000)

func regionMoved(_ region: MKCoordinateRegion, to center: CLLocationCoordinate2D)
    -> MKCoordinateRegion
{
    return MKCoordinateRegion(center: center, span: region.span)
}

func isInRegion(_ coordinate: CLLocationCoordinate2D, _ region: MKCoordinateRegion) -> Bool {
    let halfLatitude = region.span.latitudeDelta / 2
    let halfLongitude = region.span.longitudeDelta / 2
    let isLatitudeInside = abs(coordinate.latitude - region.center.latitude) <= halfLatitude
    let isLongitudeInside = abs(coordinate.longitude - region.center.longitude) <= halfLongitude
    return isLatitudeInside && isLongitudeInside
}
