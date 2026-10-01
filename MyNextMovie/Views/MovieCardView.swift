import SwiftUI

private let cardShadowColor = Color.black.opacity(0.15)
private let cardShadowRadius: CGFloat = 8
private let cardShadowOffset: CGFloat = 4
private let cardTextMaxLines = 1

/// One movie in the grid: the poster with a rating badge, the title and the subtitle under it.
struct MovieCardView: View {
    let movie: Movie

    // TODO: Lab 1, task 1. Build the card:
    // - a `VStack(alignment: .leading, spacing: spacingSmall)` with `poster` and `caption`,
    // - `poster`: `PosterView(movie:)` with `RatingBadge(movie:)` in its top trailing corner
    //   (`.overlay(alignment: .topTrailing)`, `.padding(spacingSmall)`) and a `.shadow`
    //   made of `cardShadowColor`, `cardShadowRadius` and `cardShadowOffset`,
    // - `caption`: a `VStack(alignment: .leading, spacing: spacingTiny)` with
    //   `Text(movie.title)` in `.subheadline.weight(.semibold)` and
    //   `Text(movieSubtitle(movie))` in `.caption`, `.secondary`.
    //   Both texts get `.lineLimit(cardTextMaxLines)`.
    // Split the body into computed properties, as in `MovieDetailView`.
    var body: some View {
        Text(movie.title)
    }
}

#Preview {
    MovieCardView(movie: sampleMovies[0])
        .frame(width: 170)
        .padding()
}
