#!/bin/bash
#
# Builds and tests the Examples project against each pinned swift-syntax version.
#
# The package declares a wide swift-syntax range, but any single test run only ever
# exercises whatever SwiftPM resolution happens to pick — which is the newest match,
# and silently changes when a new swift-syntax ships. (CI moved from 603 to 604 the
# day 604.0.0 was published, with no change on our side.) Examples is the right
# subject: it consumes the macro the way a real client does, so it catches breakage
# in generated code that the package's own tests can miss.
#
# Each file in Examples/CompatibilityPins is a Package.resolved pinning swift-syntax
# to one major. `--force-resolved-versions` makes SwiftPM fail rather than quietly
# upgrade past the pin, so a run that reports a version is a run that truly used it.
#
# What this does NOT cover: Examples depends on swift-mocking via `.package(path:)`,
# and SwiftPM exempts path dependencies from some checks that apply to version-pinned
# ones — notably the unsafe-flags rejection behind #124, and the macro-target
# misclassification that makes swift-syntax 602.0.0 and 603.0.0 fail for real clients
# (Examples builds fine on both). Passing here means the generated code compiles
# against that swift-syntax; it does not prove the package is consumable from a tagged
# release. Verifying that needs a throwaway package depending on a tagged clone.
#
# Usage:
#   Scripts/test-swift-syntax-compat.sh            # every pin
#   Scripts/test-swift-syntax-compat.sh 601 604    # only these
#
# Adding a major: drop a new Examples/CompatibilityPins/swift-syntax-<major>.resolved
# in place. Generate it by resolving Examples normally, then editing the swift-syntax
# pin's `version` and `revision` (the tag's commit sha) to the release you want.

set -uo pipefail

# `cd >/dev/null` because a CDPATH set in the environment makes cd echo the
# directory it landed in, which would otherwise end up inside repo_root.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
examples_dir="$repo_root/Examples"
pins_dir="$examples_dir/CompatibilityPins"

if [ ! -d "$pins_dir" ]; then
    echo "error: no pins directory at $pins_dir" >&2
    exit 1
fi

# Select pins: either the majors named as arguments, or all of them.
pins=()
if [ "$#" -gt 0 ]; then
    for major in "$@"; do
        pin="$pins_dir/swift-syntax-$major.resolved"
        if [ ! -f "$pin" ]; then
            echo "error: no pin file for major '$major' ($pin)" >&2
            exit 1
        fi
        pins+=("$pin")
    done
else
    while IFS= read -r pin; do pins+=("$pin"); done \
        < <(find "$pins_dir" -name '*.resolved' | sort)
fi

if [ "${#pins[@]}" -eq 0 ]; then
    echo "error: no pin files found in $pins_dir" >&2
    exit 1
fi

# Examples/Package.resolved is checked in, so restore it however we exit —
# including on Ctrl-C — to avoid leaving the working tree dirty.
original_resolved="$(mktemp)"
had_original=0
if [ -f "$examples_dir/Package.resolved" ]; then
    cp "$examples_dir/Package.resolved" "$original_resolved"
    had_original=1
fi

restore() {
    if [ "$had_original" -eq 1 ]; then
        cp "$original_resolved" "$examples_dir/Package.resolved"
    else
        rm -f "$examples_dir/Package.resolved"
    fi
    rm -f "$original_resolved"
}
trap restore EXIT INT TERM

failures=()

for pin in "${pins[@]}"; do
    version="$(python3 -c "
import json,sys
pins = json.load(open(sys.argv[1]))['pins']
print(next(p['state']['version'] for p in pins if p['identity'] == 'swift-syntax'))
" "$pin")"

    echo ""
    echo "=== swift-syntax $version ==="
    cp "$pin" "$examples_dir/Package.resolved"

    # A stale .build can hold checkouts from the previous pin.
    rm -rf "$examples_dir/.build"

    if swift test --package-path "$examples_dir" --force-resolved-versions; then
        # Confirm the pin actually held rather than being silently upgraded.
        actual="$(python3 -c "
import json,sys
pins = json.load(open(sys.argv[1]))['pins']
print(next(p['state']['version'] for p in pins if p['identity'] == 'swift-syntax'))
" "$examples_dir/Package.resolved")"
        if [ "$actual" != "$version" ]; then
            echo "FAIL: expected swift-syntax $version but the run used $actual"
            failures+=("$version (resolved to $actual)")
        else
            echo "PASS: swift-syntax $version"
        fi
    else
        echo "FAIL: swift-syntax $version"
        failures+=("$version")
    fi
done

echo ""
if [ "${#failures[@]}" -gt 0 ]; then
    echo "Failed: ${failures[*]}"
    exit 1
fi
echo "All ${#pins[@]} swift-syntax version(s) passed."
