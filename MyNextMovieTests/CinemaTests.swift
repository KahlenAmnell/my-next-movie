import CoreLocation
import Foundation
import MapKit
import Testing

@testable import MyNextMovie

private func makeCinema(
    id: String, name: String, phoneNumber: String = "", website: String = ""
) -> Cinema {
    return Cinema(
        id: id,
        name: name,
        address: "Wrocław",
        phoneNumber: phoneNumber,
        website: website,
        latitude: testCinemaDCF.latitude,
        longitude: testCinemaDCF.longitude
    )
}

@MainActor
struct CinemaTests {
    @Test func sortsCinemasClosestFirst() {
        let sorted = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        #expect(
            namesOf(sorted) == [
                "DCF", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki", "Helios Magnolia",
            ])
    }

    @Test func measuresDistanceOfEveryCinema() {
        let sorted = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        for cinema in sorted {
            #expect(cinema.distanceInMeters != unknownDistance)
        }
        #expect(sorted[0].distanceInMeters < sorted[1].distanceInMeters)
    }

    @Test func sortsCinemasAtTheSameDistanceByName() {
        let sameSpotB = makeCinema(id: "b", name: "B")
        let sameSpotA = makeCinema(id: "a", name: "A")

        let sorted = cinemasSortedByDistance([sameSpotB, sameSpotA], from: testUserLocation)

        #expect(namesOf(sorted) == ["A", "B"])
    }

    @Test func findsPositionOfCinema() {
        #expect(positionOfCinema(testCinemas, cinemaId: "dcf") == 2)
        #expect(positionOfCinema(testCinemas, cinemaId: "nope") == cinemaNotFound)
        #expect(containsCinema(testCinemas, cinemaId: "helios-magnolia"))
        #expect(!containsCinema(testCinemas, cinemaId: noCinemaSelected))
    }

    @Test func unknownDistanceIsEmptyText() {
        #expect(formattedDistance(unknownDistance) == "")
        #expect(formattedDistance(850) == "850 m")
        #expect(formattedDistance(2400) == "2.4 km")
    }

    @Test func phoneLinkHasOnlyDigits() {
        let url = phoneURL(testCinemaNoweHoryzonty)

        #expect(url?.absoluteString == "tel:+48717864566")
        #expect(hasPhoneNumber(testCinemaNoweHoryzonty))
    }

    @Test func noPhoneOrWebsiteMeansNoLink() {
        #expect(phoneURL(testCinemaHelios) == nil)
        #expect(!hasPhoneNumber(testCinemaHelios))
        #expect(websiteURL(testCinemaHelios) == nil)
        #expect(!hasWebsite(testCinemaHelios))
        #expect(websiteURL(testCinemaNoweHoryzonty)?.absoluteString == "https://kinonh.pl")
        #expect(hasWebsite(testCinemaNoweHoryzonty))
    }
}

@MainActor
struct WroclawCinemasTests {
    @Test func everyCinemaIsOnTheStartMap() {
        for cinema in wroclawCinemas {
            #expect(isInRegion(cinemaCoordinate(cinema), wroclawMapRegion))
        }
    }

    @Test func idsAreUnique() {
        let ids = Set(wroclawCinemas.map(\.id))

        #expect(ids.count == wroclawCinemas.count)
    }

    @Test func everyCinemaHasAddressAndWebsite() {
        for cinema in wroclawCinemas {
            #expect(!cinema.address.isEmpty)
            #expect(hasWebsite(cinema))
        }
    }

    @Test func pointOutsideRegionIsNotOnTheMap() {
        let warsaw = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)

        #expect(!isInRegion(warsaw, wroclawMapRegion))
    }
}

@MainActor
struct MapKitConversionTests {
    @Test func mapItemForCinemaKeepsNameAndPosition() {
        let item = mapItemForCinema(testCinemaDCF)

        #expect(item.name == testCinemaDCF.name)
        #expect(item.placemark.coordinate.latitude == testCinemaDCF.latitude)
        #expect(item.placemark.coordinate.longitude == testCinemaDCF.longitude)
    }

    @Test func travelModeBecomesMapKitTransportType() {
        #expect(transportTypeForMapKit(.walking) == .walking)
        #expect(transportTypeForMapKit(.driving) == .automobile)
    }
}
