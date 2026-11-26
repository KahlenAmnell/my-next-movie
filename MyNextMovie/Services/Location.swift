import CoreLocation

private let locationTimeout = Duration.seconds(10)

func findUserLocation() async -> UserLocation {
    return await withTaskGroup(of: UserLocation.self) { group in
        group.addTask { await waitForLiveLocation() }
        group.addTask { await fallbackAfterTimeout() }
        let firstAnswer = await group.next() ?? fallbackUserLocation
        group.cancelAll()
        return firstAnswer
    }
}

func lastKnownUserLocation() -> UserLocation {
    guard let location = CLLocationManager().location else {
        return fallbackUserLocation
    }
    return userLocation(from: location)
}

nonisolated private func waitForLiveLocation() async -> UserLocation {
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location {
                return userLocation(from: location)
            }
            if update.authorizationDenied {
                return fallbackUserLocation
            }
        }
    } catch {
        return fallbackUserLocation
    }
    return fallbackUserLocation
}

nonisolated private func fallbackAfterTimeout() async -> UserLocation {
    try? await Task.sleep(for: locationTimeout)
    return fallbackUserLocation
}

nonisolated private func userLocation(from location: CLLocation) -> UserLocation {
    return UserLocation(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude,
        isKnown: true)
}
