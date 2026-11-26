import Foundation
import Testing

@testable import MyNextMovie

private let testCurrentYear = 2026

private func filtersWith(
    genreIds: [Int] = [],
    fromYear: Int = noYear,
    toYear: Int = noYear,
    people: [String] = [],
    keywords: [String] = [],
    title: String = ""
) -> MovieFilters {
    return MovieFilters(
        genreIds: genreIds,
        fromYear: fromYear,
        toYear: toYear,
        people: people,
        keywords: keywords,
        title: title
    )
}

@MainActor
struct MovieFiltersValidationTests {
    @Test func keepsValidFilters() {
        let filters = filtersWith(
            genreIds: [genreIdComedy, genreIdRomance],
            fromYear: 1990,
            toYear: 1999,
            people: ["Keanu Reeves"],
            keywords: ["road trip"],
            title: "Speed"
        )

        #expect(validatedFilters(filters, currentYear: testCurrentYear) == filters)
    }

    @Test func dropsUnknownAndRepeatedGenres() {
        let filters = filtersWith(genreIds: [9999, genreIdComedy, genreIdComedy, genreIdDrama])
        let validated = validatedFilters(filters, currentYear: testCurrentYear)

        #expect(validated.genreIds == [genreIdComedy, genreIdDrama])
    }

    @Test func keepsAtMostThreeOfEach() {
        let filters = filtersWith(
            genreIds: [genreIdAction, genreIdComedy, genreIdDrama, genreIdHorror],
            people: ["A", "B", "C", "D"],
            keywords: ["a", "b", "c", "d"]
        )
        let validated = validatedFilters(filters, currentYear: testCurrentYear)

        #expect(validated.genreIds == [genreIdAction, genreIdComedy, genreIdDrama])
        #expect(validated.people == ["A", "B", "C"])
        #expect(validated.keywords == ["a", "b", "c"])
    }

    @Test func dropsYearsOutOfRange() {
        let tooEarly = filtersWith(fromYear: earliestMovieYear - 1, toYear: 1999)
        let tooLate = filtersWith(
            fromYear: 1990, toYear: testCurrentYear + yearsAheadOfToday + 1)
        let edges = filtersWith(
            fromYear: earliestMovieYear, toYear: testCurrentYear + yearsAheadOfToday)

        let validatedEarly = validatedFilters(tooEarly, currentYear: testCurrentYear)
        let validatedLate = validatedFilters(tooLate, currentYear: testCurrentYear)
        let validatedEdges = validatedFilters(edges, currentYear: testCurrentYear)

        #expect(validatedEarly.fromYear == noYear)
        #expect(validatedEarly.toYear == 1999)
        #expect(validatedLate.fromYear == 1990)
        #expect(validatedLate.toYear == noYear)
        #expect(validatedEdges == edges)
    }

    @Test func swapsYearsInWrongOrder() {
        let filters = filtersWith(fromYear: 1999, toYear: 1990)
        let validated = validatedFilters(filters, currentYear: testCurrentYear)

        #expect(validated.fromYear == 1990)
        #expect(validated.toYear == 1999)
    }

    @Test func trimsAndDropsEmptyOrRepeatedNames() {
        let filters = filtersWith(
            people: ["  Keanu Reeves ", "", "   ", "keanu reeves", "Sandra Bullock"],
            keywords: ["\nheist\n", "heist"],
            title: "  Speed \n"
        )
        let validated = validatedFilters(filters, currentYear: testCurrentYear)

        #expect(validated.people == ["Keanu Reeves", "Sandra Bullock"])
        #expect(validated.keywords == ["heist"])
        #expect(validated.title == "Speed")
    }

    @Test func emptyFiltersHaveNoFilter() {
        #expect(!hasAnyFilter(noMovieFilters))
        #expect(validatedFilters(noMovieFilters, currentYear: testCurrentYear) == noMovieFilters)
    }

    @Test func onlyUnknownGenresLeaveNoFilter() {
        let filters = filtersWith(genreIds: [9999, 8888])
        let validated = validatedFilters(filters, currentYear: testCurrentYear)

        #expect(validated == noMovieFilters)
        #expect(!hasAnyFilter(validated))
    }
}

@MainActor
struct MovieFiltersTextTests {
    @Test func summaryListsEveryFilter() {
        let filters = filtersWith(
            genreIds: [genreIdComedy],
            fromYear: 1990,
            toYear: 1999,
            people: ["Keanu Reeves"],
            keywords: ["road trip"],
            title: "Speed"
        )

        #expect(
            filtersSummary(filters)
                == "Comedy \u{00B7} 1990\u{2013}1999 \u{00B7} Keanu Reeves \u{00B7} road trip \u{00B7} Speed"
        )
        #expect(filtersSummary(noMovieFilters) == "")
    }

    @Test func yearRangeTextCoversEveryCase() {
        #expect(yearRangeText(fromYear: 1990, toYear: 1999) == "1990\u{2013}1999")
        #expect(yearRangeText(fromYear: 1990, toYear: noYear) == "1990 or later")
        #expect(yearRangeText(fromYear: noYear, toYear: 1999) == "up to 1999")
        #expect(yearRangeText(fromYear: noYear, toYear: noYear) == "")
    }

    @Test func decodesAnswerOfTheFunction() throws {
        let json = """
            {"genreIds": [35], "fromYear": 1990, "toYear": 1999,
             "people": ["Keanu Reeves"], "keywords": [], "title": ""}
            """
        let filters = try JSONDecoder().decode(MovieFilters.self, from: Data(json.utf8))

        #expect(
            filters
                == filtersWith(
                    genreIds: [genreIdComedy], fromYear: 1990, toYear: 1999,
                    people: ["Keanu Reeves"]))
    }

    // TODO: Lab 7, path A only. errorAnswerShowsItsMessage tests `functionErrorMessage`
    // from Supabase.swift, so it is added together with that function (task 3).
}
