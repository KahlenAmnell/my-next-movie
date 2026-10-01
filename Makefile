PROJECT     := MyNextMovie.xcodeproj
SCHEME      := MyNextMovie
DESTINATION ?= platform=iOS Simulator,name=iPhone 17
XCODEBUILD  := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -quiet

.PHONY: help format lint build release analyze test check

help:
	@printf "%-8s %s\n" \
		"format"  "format all Swift files in place" \
		"lint"    "check formatting, lint rules and indentation depth" \
		"build"   "Debug build, warnings are errors" \
		"release" "Release build, warnings are errors" \
		"analyze" "run the Clang static analyzer" \
		"test"    "run the test plan on the simulator, with code coverage" \
		"check"   "everything above except format, run it before you push"

format:
	xcrun swift-format format --in-place --recursive --parallel MyNextMovie MyNextMovieTests

lint:
	scripts/lint.sh --strict

build:
	$(XCODEBUILD) -configuration Debug -destination 'generic/platform=iOS Simulator' \
		build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

release:
	$(XCODEBUILD) -configuration Release -destination 'generic/platform=iOS Simulator' build

analyze:
	$(XCODEBUILD) -destination 'generic/platform=iOS Simulator' analyze

test:
	$(XCODEBUILD) -destination '$(DESTINATION)' test

check: lint build release analyze test
