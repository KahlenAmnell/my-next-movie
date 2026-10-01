#!/bin/sh
# Lints the Swift sources: swift-format rules plus the indentation limit.
#
#   scripts/lint.sh           findings are warnings, exit code 0 (Xcode build phase)
#   scripts/lint.sh --strict  findings are errors, exit code 1 (CI)

cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
sources="$root/MyNextMovie $root/MyNextMovieTests"

strict=""
level=warning
if [ "${1:-}" = "--strict" ]; then
    strict=--strict
    level=error
fi

# Xcode on macOS, the plain Swift toolchain on Linux.
if command -v xcrun >/dev/null 2>&1; then
    format="xcrun swift-format"
else
    format="swift format"
fi

status=0
$format lint $strict --recursive --parallel $sources || status=1

# Like the Linux kernel: at most 3 levels of indentation inside a function.
# One more level belongs to the enclosing type, so with 4 spaces per level
# no line may start deeper than column 17.
files=$(find $sources -name '*.swift' | sort)
awk -v level="$level" '
    /^ *$/ { next }
    {
        match($0, /^ */)
        if (RLENGTH > 16) {
            printf "%s:%d:%d: %s: [MaxIndentation] more than 3 levels of indentation, extract a function or a view\n", FILENAME, FNR, RLENGTH + 1, level
            found = 1
        }
    }
    END { exit found }
' $files || status=1

if [ -z "$strict" ]; then
    exit 0
fi
exit $status
