# my-next-movie

Projekt startowy do laboratoriów z przedmiotu **Zaawansowane programowanie na platformę iOS**.

Aplikacja rekomenduje filmy. Dane pochodzą z TMDB, konto i zapisane filmy z Supabase.

## Co jest w projekcie

```
MyNextMovie/
  Models/        Movie, gatunki i funkcje pomocnicze
  Services/      MovieLoader, przykładowe filmy
  ViewModels/    stan ekranu listy
  Views/         lista i szczegóły filmu, Components/ ze wspólnymi elementami
  Config/        odczyt kluczy API
MyNextMovieTests/        testy jednostkowe (Swift Testing)
docs/                    zadania na kolejne laboratoria
MyNextMovie.xctestplan   plan testów
Config/                  ustawienia builda (.xcconfig), Info.plist
scripts/lint.sh          lint: swift-format i limit wcięć
```

Architektura: SwiftUI + MVVM. Nowe pliki dodane do folderów `MyNextMovie/` i `MyNextMovieTests/` trafiają do projektu same.

## Styl kodu

Projekt jest napisany prosto, bliżej C niż typowego Swifta:

- dane to struktury bez metod, np. `Movie`,
- logika to zwykłe funkcje, np. `releaseYear(movie)`,
- zależności przekazujesz jako funkcje, np. `MovieListViewModel(loadMovies: loadSampleMovies)`,
- brak wartości to wartość pusta, jak w C: `""` dla tekstu, `0` dla gatunku, `-1` dla indeksu,
- zamiast `if let`, `guard let`, `map` i `filter` piszesz zwykłe `if` i pętlę `for`,
- stan ekranu to `enum` bez dołączonych wartości, a dane leżą obok w zwykłych polach,
- **maksymalnie 3 poziomy wcięć w funkcji**, jak w jądrze Linuksa. Głębiej? Wydziel funkcję albo widok.
- nazwy mówią, czego dotyczą: `positionInGenreTable`, `selectedGenreId`, `trimmedQuery`. Żadnych `i`, `j`, `x`. Długa nazwa jest lepsza niż niejasna,
- zamiast magicznych liczb i napisów są stałe: `genreIdAction` zamiast `28`, `noGenreId` zamiast `0`, `spacingLarge` zamiast `16`. Wyjątek to teksty widoczne na ekranie, bo Xcode wyciąga je z widoków do tłumaczeń.

Klasa jest tylko tam, gdzie wymaga jej SwiftUI: ViewModel z `@Observable`. Widoki to struktury, bo tak działa SwiftUI.

Programowanie obiektowe nie jest zakazane. Klasy, protokoły i metody możesz stosować tam, gdzie uznasz je za lepsze. Wybór należy do Ciebie.

## Zadania

Zadania na każde zajęcia są w folderze `docs/`. Zaczynasz od [docs/lab1.md](docs/lab1.md).

Miejsca do uzupełnienia oznacza komentarz `// TODO: Lab N`. Listę wszystkich znajdziesz w Xcode: Find Navigator (⌘⇧F), szukaj `TODO: Lab`.

Testy są dwojakie:

- **gotowe**. Na starcie część z nich nie przechodzi. Przejdą, gdy uzupełnisz kod.
- **do napisania**. Mają `@Test(.disabled(...))` i pustą treść. Komentarz nad testem mówi, co sprawdzić. Napisz test i usuń `.disabled(...)`.

Laboratorium jest skończone, gdy `make check` przechodzi i żaden test nie jest pominięty.

## Formatowanie i lint

Kod ma się budować **bez żadnych ostrzeżeń**.

Reguły formatowania są w pliku `.swift-format`. Narzędzie `swift-format` jest wbudowane w Xcode, niczego nie instalujesz.

- W Xcode formatujesz plik skrótem ⌃⇧I (Editor, Structure, Format File with 'swift-format').
- Każdy build uruchamia `scripts/lint.sh`. Uwagi, także o zbyt głębokich wcięciach, widzisz w Xcode jako ostrzeżenia.
- Na GitHubie lint sprawdza każdy push (Actions, Lint).
- Build w konfiguracji Release traktuje ostrzeżenia jako błędy.

Z terminala:

```sh
make format   # formatuje wszystkie pliki
make lint     # formatowanie, reguły i limit wcięć
make build    # build Debug, ostrzeżenia są błędami
make release  # build Release, ostrzeżenia są błędami
make analyze  # statyczny analizator
make test     # testy na symulatorze, z pokryciem kodu
make check    # wszystko poza format, przed pushem
```

Inny symulator podajesz tak: `make test DESTINATION='platform=iOS Simulator,name=iPhone 16'`.

## Konfiguracja Xcode

Ustawienia builda są w plikach `.xcconfig`, a nie w `project.pbxproj`. Łatwo je czytać i porównywać w Git.

```
Config/Shared.xcconfig    wspólne dla całego projektu: wersja iOS, Swift 6, podpisywanie
Config/Debug.xcconfig     szybki build bez optymalizacji
Config/Release.xcconfig   build z optymalizacją, ostrzeżenia są błędami
Config/App.xcconfig       aplikacja: bundle id, Info.plist, klucze API
Config/Tests.xcconfig     testy jednostkowe
```

Testy uruchamia plan `MyNextMovie.xctestplan`. Zbiera pokrycie kodu (Report navigator, Coverage) i uruchamia testy w losowej kolejności, żeby żaden test nie zależał od innego.

## Wymagania

- Xcode 26 lub nowszy
- Konto na GitHubie
- Konto w TMDB i klucz API
- Konto w Supabase

## Start

Robisz to raz, na pierwszych zajęciach.

1. Na GitHubie utwórz **puste, prywatne** repozytorium, np. `my-next-movie`. Bez README i bez `.gitignore`.
2. Sklonuj repozytorium przedmiotu i podepnij swoje:

```sh
git clone https://github.com/fwsoft/my-next-movie.git my-next-movie
cd my-next-movie
git remote rename origin upstream
git remote add origin https://github.com/TWOJ_LOGIN/my-next-movie.git
git push -u origin main
```

3. W swoim repozytorium: Settings, Collaborators. Dodaj prowadzącego.
4. Skopiuj `Config/Secrets.xcconfig.example` jako `Config/Secrets.xcconfig` i wpisz klucze.
5. Otwórz `MyNextMovie.xcodeproj`, uruchom aplikację (⌘R) i testy (⌘U).

Nie używaj forka. Fork publicznego repozytorium jest zawsze publiczny.

## Po każdych zajęciach

Wypchnij aktualny postęp na GitHub, nawet jeśli zadanie nie jest skończone:

```sh
git add .
git commit -m "feat: lab 2, movie list screen"
git push
```

Postęp sprawdzam w historii repozytorium. Projekt oddany w całości na końcu, bez postępów po drodze, nie zalicza laboratoriów.

## Nowe laboratoria

Materiały do kolejnych zajęć pojawiają się w repozytorium przedmiotu. Pobierasz je tak:

```sh
git pull upstream main
git push
```

Jeśli Git zgłosi konflikt, popraw zaznaczone pliki, potem `git add` i `git commit`.

## Klucze API

Klucze wpisujesz w `Config/Secrets.xcconfig`. Ten plik jest w `.gitignore` i nie trafia do repozytorium.

W kodzie odczytujesz je funkcjami z `MyNextMovie/Config/AppConfig.swift`:

```swift
tmdbAPIKey()
supabaseURL()
supabaseAnonKey()
```

Klucz TMDB i klucz `anon` z Supabase mogą być w aplikacji. Klucz dostawcy AI nie. Jego używaj tylko po stronie serwera, np. w Supabase Edge Function.

Na własnym iPhonie zmień `PRODUCT_BUNDLE_IDENTIFIER` w `Config/App.xcconfig` na swój i wybierz swój zespół w Signing & Capabilities. Symulator działa bez zmian.

## Oddanie projektu

Na koniec semestru oddajesz ZIP z kodem na Moodle.

Do zaliczenia laboratoriów potrzebne są oba warunki:

- postęp wypchnięty po każdych zajęciach,
- ZIP z kodem na Moodle.

## Dokumentacja

- Swift: https://docs.swift.org/swift-book
- SwiftUI: https://developer.apple.com/documentation/swiftui
- Swift Testing: https://developer.apple.com/documentation/testing
- TMDB: https://developer.themoviedb.org/docs
- Supabase: https://supabase.com/docs/reference/swift
