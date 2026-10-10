#!/bin/bash
#
# Runs the test suite with coverage instrumentation and exports an lcov report
# for Codecov.
#
# Why this isn't just `swift test --enable-code-coverage`: SwiftPM writes a
# profdata file but no lcov, and the raw llvm-cov export over the test binary
# covers everything linked into it — 364 files here, of which only 39 are ours.
# The rest is dependency checkouts under .build (CustomDump, MacroTesting,
# swift-syntax) plus the test targets themselves. Reporting that would make the
# badge a number about other people's code, and it moves whenever a dependency
# resolves differently. So llvm-cov is scoped to Sources/ explicitly.
#
# Tests and generated code are excluded for the same reason they usually are:
# Tests/ measures itself (a test file is ~100% covered by definition, which
# inflates the total), and the .derived/runner.swift SwiftPM synthesizes is not
# authored code at all.
#
# Usage:
#   Scripts/coverage.sh                   # run tests, write coverage.lcov
#   Scripts/coverage.sh --report          # also print the per-file table
#   Scripts/coverage.sh --skip-tests      # reuse an existing profdata

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
cd "$repo_root" || exit 1

run_tests=1
show_report=0
for arg in "$@"; do
    case "$arg" in
        --skip-tests) run_tests=0 ;;
        --report)     show_report=1 ;;
        *) echo "error: unknown argument '$arg'" >&2; exit 1 ;;
    esac
done

if [ "$run_tests" -eq 1 ]; then
    if ! swift test --enable-code-coverage; then
        echo "error: tests failed; not exporting coverage" >&2
        exit 1
    fi
fi

bin_path="$(swift build --show-bin-path)"
profdata="$bin_path/codecov/default.profdata"

if [ ! -f "$profdata" ]; then
    echo "error: no profdata at $profdata (run without --skip-tests)" >&2
    exit 1
fi

# The bundle name follows the package name, but glob it rather than hardcode:
# SwiftPM renames it if the package is renamed, and on Linux it's a bare
# executable with no .xctest wrapper at all.
test_binary=""
for bundle in "$bin_path"/*.xctest; do
    [ -e "$bundle" ] || continue
    if [ -d "$bundle" ]; then
        test_binary="$bundle/Contents/MacOS/$(basename "$bundle" .xctest)"  # macOS
    else
        test_binary="$bundle"                                               # Linux
    fi
    break
done

if [ -z "$test_binary" ] || [ ! -f "$test_binary" ]; then
    echo "error: could not locate a test binary in $bin_path" >&2
    exit 1
fi

# Passing Sources/ as a positional filter makes llvm-cov restrict the report to
# files under it, which drops both the dependency checkouts and Tests/.
xcrun llvm-cov export \
    -format=lcov \
    -instr-profile "$profdata" \
    "$test_binary" \
    "$repo_root/Sources" \
    > "$repo_root/coverage.lcov"

if [ ! -s "$repo_root/coverage.lcov" ]; then
    echo "error: coverage.lcov is empty" >&2
    exit 1
fi

echo "Wrote coverage.lcov ($(grep -c '^SF:' "$repo_root/coverage.lcov") files)"

if [ "$show_report" -eq 1 ]; then
    echo ""
    xcrun llvm-cov report \
        -instr-profile "$profdata" \
        "$test_binary" \
        "$repo_root/Sources"
fi
