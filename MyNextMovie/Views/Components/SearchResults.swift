import SwiftUI

let searchResultThumbnailWidth: CGFloat = 56
let searchResultTitleMaxLines = 2

struct SearchResults: View {
    let movies: [Movie]
    let query: String
    
    @ViewBuilder
    var body: some View {
        if movies.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(movies) { movie in
                SearchResultRow(movie: movie)
            }
            .listStyle(.plain)
        }
    }
}

struct SearchResultRow: View {
    let movie: Movie
    
    var body: some View {
        NavigationLink(value: movie) {
            HStack(spacing: spacingMedium) {
                PosterView(movie: movie, cornerRadius: thumbnailCornerRadius).frame(width: searchResultThumbnailWidth)
                VStack(alignment: .leading, spacing: spacingExtraSmall) {
                    Text(movie.title).font(.headline).lineLimit(searchResultTitleMaxLines)
                    Text(movieSubtitle(movie)).font(.subheadline).foregroundColor(.secondary)
                    Text(ratingWithStar(movie)).font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, spacingExtraSmall)
        }
    }
}
