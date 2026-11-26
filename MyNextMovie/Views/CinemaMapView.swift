import MapKit
import SwiftUI

enum CinemaMapPlacement {
    case tab
    case sheet
}

private let mapHeightShare = 0.45
private let selectedRowOpacity = 0.15

struct CinemaMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CinemaMapViewModel
    @State private var cameraPosition = MapCameraPosition.region(wroclawMapRegion)
    @State private var path: [Cinema] = []
    private let findRoute: CinemaRouteFinder
    private let placement: CinemaMapPlacement

    init(
        viewModel: CinemaMapViewModel,
        findRoute: @escaping CinemaRouteFinder,
        placement: CinemaMapPlacement
    ) {
        _viewModel = State(initialValue: viewModel)
        self.findRoute = findRoute
        self.placement = placement
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                map.containerRelativeFrame(.vertical) { height, _ in height * mapHeightShare }
                locationUnavailableNotice
                cinemaList
            }
            .navigationTitle("Cinemas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneButton }
            .navigationDestination(for: Cinema.self) { cinema in detailView(cinema) }
        }
        .task { await viewModel.locateUserIfNeeded() }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition, selection: mapSelection) {
            UserAnnotation()
            ForEach(viewModel.cinemas) { cinema in
                cinemaMarker(cinema)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange { context in viewModel.visibleRegion = context.region }
    }

    private func cinemaMarker(_ cinema: Cinema) -> some MapContent {
        Marker(
            cinema.name, systemImage: symbolNameCinema,
            coordinate: cinemaCoordinate(cinema)
        )
        .tag(cinema.id)
    }

    private var mapSelection: Binding<String?> {
        return Binding(
            get: { isAnyCinemaSelected ? viewModel.selectedCinemaId : nil },
            set: { viewModel.selectedCinemaId = $0 ?? noCinemaSelected }
        )
    }

    private var isAnyCinemaSelected: Bool {
        return viewModel.selectedCinemaId != noCinemaSelected
    }

    // MARK: - List

    @ViewBuilder
    private var locationUnavailableNotice: some View {
        if viewModel.isLocationUnavailable {
            Label(
                "Turn on location to see distances and routes.",
                systemImage: symbolNameLocationOff
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
    }

    private var cinemaList: some View {
        ScrollViewReader { proxy in
            List(viewModel.cinemas) { cinema in listRow(cinema) }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedCinemaId) { _, selectedId in
                scrollToCinema(selectedId, using: proxy)
            }
        }
    }

    private func listRow(_ cinema: Cinema) -> some View {
        cinemaRow(cinema)
            .id(cinema.id)
            .listRowBackground(rowBackground(for: cinema))
    }

    private func cinemaRow(_ cinema: Cinema) -> some View {
        HStack {
            Button {
                selectFromList(cinema)
            } label: {
                cinemaTexts(cinema).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                path.append(cinema)
            } label: {
                Image(systemName: symbolNameDetails)
            }
            .accessibilityLabel("Details of \(cinema.name)")
        }
        .buttonStyle(.plain)
    }

    private func cinemaTexts(_ cinema: Cinema) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cinema.name).font(.headline)
            Text(cinema.address).font(.subheadline).foregroundStyle(.secondary)
            Text(formattedDistance(cinema.distanceInMeters))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func detailView(_ cinema: Cinema) -> some View {
        CinemaDetailView(
            viewModel: CinemaDetailViewModel(
                cinema: cinema,
                userLocation: viewModel.userLocation,
                findRoute: findRoute))
    }

    private func rowBackground(for cinema: Cinema) -> Color {
        let isSelected = cinema.id == viewModel.selectedCinemaId
        return isSelected ? Color.accentColor.opacity(selectedRowOpacity) : Color.clear
    }

    // MARK: - Selection

    private func selectFromList(_ cinema: Cinema) {
        viewModel.toggleCinema(cinema)
        if viewModel.selectedCinemaId == cinema.id {
            let region = regionMoved(viewModel.visibleRegion, to: cinemaCoordinate(cinema))
            withAnimation { cameraPosition = .region(region) }
        }
    }

    private func scrollToCinema(_ cinemaId: String, using proxy: ScrollViewProxy) {
        guard containsCinema(viewModel.cinemas, cinemaId: cinemaId) else { return }
        withAnimation { proxy.scrollTo(cinemaId, anchor: .center) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        if placement == .sheet {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    CinemaMapView(
        viewModel: CinemaMapViewModel(
            cinemas: wroclawCinemas,
            findUserLocation: { fallbackUserLocation }),
        findRoute: { _, _, _ in noRoute },
        placement: .tab)
}
