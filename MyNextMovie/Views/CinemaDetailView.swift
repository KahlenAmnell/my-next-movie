import MapKit
import SwiftUI

private let detailMapHeight: CGFloat = 220
private let lookAroundHeight: CGFloat = 200
private let cinemaAreaMeters = 1500.0
private let routePadding = 0.2
private let routeLineWidth: CGFloat = 5

struct CinemaDetailView: View {
    @State private var viewModel: CinemaDetailViewModel
    @State private var cameraPosition: MapCameraPosition
    @State private var lookAroundScene: MKLookAroundScene?

    init(viewModel: CinemaDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
        let area = MKCoordinateRegion(
            center: cinemaCoordinate(viewModel.cinema),
            latitudinalMeters: cinemaAreaMeters,
            longitudinalMeters: cinemaAreaMeters)
        _cameraPosition = State(initialValue: .region(area))
    }

    var body: some View {
        List {
            mapSection
            addressSection
            wayThereSection
            linksSection
            lookAroundSection
        }
        .navigationTitle(viewModel.cinema.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.travelMode) { await viewModel.loadRoute() }
        .task { lookAroundScene = await findLookAroundScene(viewModel.cinema) }
        .onChange(of: viewModel.routeState) { _, newState in
            if newState == .loaded { showWholeRoute() }
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        Section {
            Map(position: $cameraPosition) {
                UserAnnotation()
                cinemaMarker
                routeLine
            }
            .frame(height: detailMapHeight)
            .listRowInsets(EdgeInsets())
        }
    }

    private var cinemaMarker: some MapContent {
        Marker(
            viewModel.cinema.name, systemImage: symbolNameCinema,
            coordinate: cinemaCoordinate(viewModel.cinema))
    }

    @MapContentBuilder
    private var routeLine: some MapContent {
        if viewModel.routeState == .loaded {
            MapPolyline(viewModel.route.line)
                .stroke(.blue, lineWidth: routeLineWidth)
        }
    }

    private var addressSection: some View {
        Section("Address") {
            Text(viewModel.cinema.address)
            let distance = formattedDistance(viewModel.cinema.distanceInMeters)
            if !distance.isEmpty {
                Text(distance).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var wayThereSection: some View {
        Section("Way There") {
            if viewModel.canFindRoute {
                travelModePicker
                routeStatus
            } else {
                locationOffNotice
            }
        }
    }

    private var locationOffNotice: some View {
        Label(
            "Turn on location to see distances and routes.",
            systemImage: symbolNameLocationOff
        )
        .foregroundStyle(.secondary)
    }

    private var travelModePicker: some View {
        Picker("Travel mode", selection: $viewModel.travelMode) {
            Label("Walk", systemImage: symbolNameWalking).tag(TravelMode.walking)
            Label("Drive", systemImage: symbolNameDriving).tag(TravelMode.driving)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var routeStatus: some View {
        switch viewModel.routeState {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
        case .loaded:
            Text(viewModel.routeSummary(viewModel.route))
        case .failed:
            Text(viewModel.errorMessage).foregroundStyle(.secondary)
        }
    }

    private var linksSection: some View {
        Section {
            directionsButton
            phoneLink
            websiteLink
        }
    }

    private var directionsButton: some View {
        Button {
            openCinemaInMaps(viewModel.cinema, travelMode: viewModel.travelMode)
        } label: {
            Label("Directions in Maps", systemImage: symbolNameDirections)
        }
    }

    @ViewBuilder
    private var phoneLink: some View {
        if let phone = phoneURL(viewModel.cinema) {
            Link(destination: phone) {
                Label(viewModel.cinema.phoneNumber, systemImage: symbolNamePhone)
            }
        }
    }

    @ViewBuilder
    private var websiteLink: some View {
        if let website = websiteURL(viewModel.cinema) {
            Link(destination: website) {
                Label("Website", systemImage: symbolNameWebsite)
            }
        }
    }

    @ViewBuilder
    private var lookAroundSection: some View {
        if let lookAroundScene {
            Section("Look Around") { lookAroundPreview(lookAroundScene) }
        }
    }

    private func lookAroundPreview(_ scene: MKLookAroundScene) -> some View {
        LookAroundPreview(initialScene: scene)
            .frame(height: lookAroundHeight)
            .listRowInsets(EdgeInsets())
    }

    // MARK: - Map camera

    private func showWholeRoute() {
        let rect = viewModel.route.line.boundingMapRect
        let padded = rect.insetBy(dx: -rect.width * routePadding, dy: -rect.height * routePadding)
        withAnimation { cameraPosition = .rect(padded) }
    }
}

#Preview {
    NavigationStack {
        CinemaDetailView(
            viewModel: CinemaDetailViewModel(
                cinema: wroclawCinemas[0],
                userLocation: fallbackUserLocation,
                findRoute: { _, _, _ in noRoute }))
    }
}
