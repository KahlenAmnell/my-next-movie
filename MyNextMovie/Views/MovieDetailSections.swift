import SwiftUI

import SwiftUI

struct MovieDetailSections: View {
    let details: MovieDetails
    // Upewnij się, że watchRegionCode jest tutaj dostępny (np. jako pole z @Environment lub zmienna)
    // var watchRegionCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            trailerSection
            castSection
            watchProvidersSection
            recommendationsSection
        }
        .padding(.horizontal)
    }

    // MARK: - Sections

    @ViewBuilder
    private var trailerSection: some View {
        if hasTrailer(details), let url = trailerURL(details) {
            Link(destination: url) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Watch Trailer")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private var castSection: some View {
        if let cast = details.credits?.cast, !cast.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cast")
                    .font(.title2)
                    .bold()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(cast.prefix(15)) { member in
                            castMemberView(member: member)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func castMemberView(member: CastMember) -> some View {
        VStack(alignment: .center, spacing: 6) {
            if let url = profileURL(member) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .frame(width: 70, height: 70)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
            }

            Text(member.name)
                .font(.caption)
                .bold()
                .multilineTextAlignment(.center)
                .frame(width: 80)

            if let character = member.character {
                Text(character)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
    }

    @ViewBuilder
    private var watchProvidersSection: some View {
        // Uwaga: upewnij się, że watchRegionCode jest zdefiniowany w tej strukturze
        let providers = watchProviders(details, regionCode: "US")
        if hasWatchProviders(providers) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where to Watch")
                    .font(.title2)
                    .bold()

                if let flatrate = providers.flatrate, !flatrate.isEmpty {
                    providerGroup(title: "Stream", providers: flatrate)
                }
                if let rent = providers.rent, !rent.isEmpty {
                    providerGroup(title: "Rent", providers: rent)
                }
                if let buy = providers.buy, !buy.isEmpty {
                    providerGroup(title: "Buy", providers: buy)
                }

                Text("Streaming data from JustWatch")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if let recommendations = details.recommendations?.results, !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("More Like This")
                    .font(.title2)
                    .bold()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recommendations) { movie in
                            NavigationLink(destination: MovieDetailView(movie: movie, loadDetails: fetchMovieDetails)) {
                                MovieCardView(movie: movie)
                            }
                        }
                    }
                }
            }
        }
    }
}

@ViewBuilder
private func providerGroup(title: String, providers: [WatchProvider]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.secondary)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(providers) { provider in
                    HStack(spacing: 8) {
                        if let url = logoURL(provider) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } else {
                                    Color.gray.opacity(0.3)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .cornerRadius(6)
                        }
                        Text(provider.providerName)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
}
