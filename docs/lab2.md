# Lab 2: ekran wyszukiwania

Na tych zajeciach dodajesz drugi ekran aplikacji. Uzytkownik wpisuje tytul albo slowo z opisu filmu i wybiera gatunek. Lista wynikow odswieza sie sama w trakcie pisania.

Dane nadal sa przykladowe, z `Services/SampleMovies.swift`. Wyszukiwanie w TMDB dojdzie na kolejnych zajeciach. Ekran sie nie zmieni, podmienisz tylko funkcje, ktora szuka filmow.

## Zanim zaczniesz

1. Lab 1 musi byc skonczony i wypchniety.
2. Pobierz nowe pliki:

```sh
git pull upstream main
git push
```

3. Uruchom aplikacje (Cmd+R). Wyglada tak samo jak po lab 1. Zakladka Search pojawi sie dopiero po zadaniu 2.
4. Uruchom testy (Cmd+U). Czesc nowych testow nie przechodzi, czesc jest pominieta. Tak ma byc.

## Nowe pliki

```
MyNextMovie/Models/Search.swift               filtrowanie filmow
MyNextMovie/ViewModels/SearchViewModel.swift  stan ekranu wyszukiwania
MyNextMovie/Views/SearchView.swift            ekran wyszukiwania
MyNextMovieTests/SearchTests.swift            testy
```

Zmienione pliki:

```
MyNextMovie/Services/MovieLoader.swift   nowy typ MovieSearch
MyNextMovie/Services/SampleMovies.swift  nowa funkcja searchSampleMovies
MyNextMovie/MyNextMovieApp.swift         miejsce na zakladke Search
```

Miejsca do uzupelnienia znajdziesz w Xcode: Find Navigator (Cmd+Shift+F), szukaj `TODO: Lab 2`.

## Jak to dziala

Ekran listy z lab 1 dostaje funkcje, ktora laduje filmy:

```swift
typealias MovieLoader = () async throws -> [Movie]
```

Ekran wyszukiwania dostaje funkcje, ktora szuka filmow po tekscie i gatunku:

```swift
typealias MovieSearch = (_ query: String, _ genreId: Int) async throws -> [Movie]
```

Teraz ta funkcja to `searchSampleMovies`. Filtruje przykladowe filmy funkcja `filterMovies`. Na kolejnych zajeciach w to miejsce wejdzie zapytanie do TMDB o tym samym typie. ViewModel i widok zostana bez zmian.

`noGenreId` oznacza "dowolny gatunek". Pusty tekst oznacza "dowolny tytul".

Kiedy uzytkownik pisze, kazda litera zmienia `viewModel.query`. Widok nie szuka po kazdej literze. Czeka 300 ms od ostatniej zmiany i dopiero wtedy wola `viewModel.search()`. Robi to `.task(id:)` w `SearchView`. Gdy `id` sie zmienia, SwiftUI przerywa poprzednie zadanie i startuje nowe. Ten kod jest gotowy. Przeczytaj go, bo pojawi sie na kolejnych zajeciach.

## Zadanie 1: logika wyszukiwania

Funkcje w `Models/Search.swift`:

1. `movieContainsText`: czy tekst jest w tytule albo w opisie filmu. Uzyj gotowej funkcji `textContains`. Ona ignoruje wielkosc liter i polskie znaki.
2. `filterMovies`: filmy, ktore pasuja do tekstu i do gatunku.

Pisz `filterMovies` tak:

```swift
for movie in movies {
    if warunek_gatunku_nie_pasuje {
        continue
    }
    if warunek_tekstu_nie_pasuje {
        continue
    }
    matchingMovies.append(movie)
}
```

`continue` przechodzi do nastepnego filmu. Dzieki temu nie wkladasz jednego `if` w drugi i nie przekraczasz trzech poziomow wciec.

Metody w `ViewModels/SearchViewModel.swift`:

1. `search`: szuka filmow i ustawia `state`. Wzoruj sie na `load` z `MovieListViewModel`. Gdy tekst jest pusty i nie wybrano gatunku, nie szukaj. Ustaw wtedy `.idle`.
2. `toggleGenre`: pierwsze klikniecie wybiera gatunek, drugie go odznacza.

Testy do napisania w `MyNextMovieTests/SearchTests.swift`:

1. `FilterMoviesTests/ignoresDiacritics`
2. `FilterMoviesTests/combinesQueryAndGenre`
3. `SearchViewModelTests/passesTrimmedQueryAndGenreToSearch`
4. `SearchViewModelTests/togglingSelectedGenreClearsIt`

Komentarz nad kazdym testem mowi, co sprawdzic. Napisz test i usun `.disabled(...)`. Test, ktory wola `await`, musi byc `async`.

Po tym zadaniu testy z `SearchTests.swift` przechodza. Na ekranie jeszcze nic nie widac.

## Zadanie 2: ekran

Najpierw zakladka. W `MyNextMovieApp.swift` dodaj drugi `Tab` z `SearchView`. Dokladny kod jest w komentarzu `TODO`. Uruchom aplikacje. Na dole jest zakladka z lupa. Ekran juz dziala, ale wyniki to tylko napis z ich liczba.

Teraz widoki w `Views/SearchView.swift`:

1. `GenreFilter`: wiersz wszystkich gatunkow, przewijany w bok. Podobny wiersz zrobiles w lab 1, to `GenreRow` w `MovieDetailView.swift`.
2. `genreFilterChip`: `Button`, ktory wola `toggleGenre`. Wybrany gatunek ma wypelniony chip, reszta jest blada. `GenreChip` ma do tego parametr `isSelected`.
3. `SearchResults`: lista wynikow albo komunikat "brak wynikow". Gotowy komunikat to `ContentUnavailableView.search(text:)`.
4. `SearchResultRow`: maly plakat po lewej, tytul, rok z gatunkiem i ocena po prawej. Klikniecie otwiera szczegoly filmu, tak jak w siatce z lab 1.

Sprawdzaj kazdy widok w podgladzie (Canvas, Cmd+Option+Enter) w `SearchView.swift`. Podglad uzywa przykladowych filmow.

Sprawdz w aplikacji:

1. "matrix" znajduje The Matrix.
2. "wormhole" znajduje Interstellar, bo to slowo jest w opisie.
3. Gatunek Animation bez tekstu pokazuje Spirited Away.
4. "matrix" z gatunkiem Animation pokazuje "No Results".
5. Drugie klikniecie w gatunek go odznacza.
6. Klikniecie w wynik otwiera szczegoly filmu.

## Koniec zajec

1. Build (Cmd+B) bez ostrzezen. Testy (Cmd+U) przechodza, zaden nie jest pominiety.
2. Commit i push:

```sh
git add .
git commit -m "feat: lab 2, search screen"
git push
```

## Na kolejne zajecia

Wpisz klucz TMDB do `Config/Secrets.xcconfig`. Instrukcja jest w README, w sekcji Klucze API. Bez klucza nie pobierzesz prawdziwych filmow.

## Dokumentacja

- `searchable`: https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:prompt:)
- `task(id:)`: https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:)
- `List`: https://developer.apple.com/documentation/swiftui/list
- `Button`: https://developer.apple.com/documentation/swiftui/button
- `ContentUnavailableView`: https://developer.apple.com/documentation/swiftui/contentunavailableview
- `Tab`: https://developer.apple.com/documentation/swiftui/tab
