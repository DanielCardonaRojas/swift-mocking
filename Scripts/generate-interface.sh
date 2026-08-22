#!/bin/bash
#
# Generates `.swiftinterface` API references for the agent skill.
#
# The skill (skills/swift-mocking/) points agents at these files as the
# authoritative signature reference, so they can check an API's exact shape
# instead of guessing from prose.
#
# Library evolution can't be enabled package-wide — the swift-syntax dependency
# does not build under it — so Package.swift applies it to the two library
# targets only, gated on SWIFTMOCKING_EMIT_INTERFACE.
#
# Caveat: `Sendable` is a marker protocol, and the compiler elides marker
# protocols from `where` clauses in emitted interfaces. So a source signature of
# `thenThrow<E: Error & Sendable>` prints here as `where E : Error`. The
# constraint is still enforced — consult the source when Sendable matters.
#
# Usage: ./Scripts/generate-interface.sh

set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="skills/swift-mocking/references/interface"
BUILD_DIR=".build/arm64-apple-macosx/release/Modules"

echo "Building with module interface emission..."
# SwiftMockingTestSupport's interface fails the compiler's round-trip
# verification (an XCTestCase subclass re-declares inherited @objc
# initializers). The file is still written correctly, so a non-zero exit here
# is expected and not fatal.
SWIFTMOCKING_EMIT_INTERFACE=1 swift build -c release --product SwiftMocking >/dev/null 2>&1 || true

mkdir -p "$OUT_DIR"

clean_interface() {
    local src="$1"
    local dst="$2"
    local module="$3"

    if [ ! -f "$src" ]; then
        echo "error: expected interface not found at $src" >&2
        return 1
    fi

    # Strip compiler bookkeeping and non-public surface, then unqualify the
    # names an agent would actually type. perl (not sed) because BSD sed on
    # macOS has no \b word-boundary support.
    perl -pe '
        next if s/^\/\/ swift-(interface-format-version|compiler-version|module-flags).*\n//;
        next if s/^ *\@objc deinit\n//;
        next if s/^ *\@usableFromInline\n//;
        next if /internal /  and $_ = "";
        s/\@_hasMissingDesignatedInitializers //g;
        s/\@inlinable //g;
        s/\b(SwiftMocking|Swift|_Concurrency)\.//g;
    ' "$src" > "$dst"

    echo "  $module → $dst ($(wc -l < "$dst" | tr -d ' ') lines)"
}

echo "Writing interfaces..."
clean_interface "$BUILD_DIR/SwiftMocking.swiftinterface" \
    "$OUT_DIR/SwiftMocking.swiftinterface" "SwiftMocking"
clean_interface "$BUILD_DIR/SwiftMockingTestSupport.swiftinterface" \
    "$OUT_DIR/SwiftMockingTestSupport.swiftinterface" "SwiftMockingTestSupport"

echo "Done."
