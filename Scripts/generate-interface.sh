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
    #
    # Dropping an `internal` declaration must take its whole body with it.
    # Deleting only the opening line orphans the closing brace, which leaves
    # the file unparseable — `internal struct Return<…> {` used to vanish while
    # its `}` survived and closed the *previous* declaration. So when an
    # internal line opens a brace, skip through the matching close; internal
    # members inside a public type (`internal func get() -> R`) are single
    # lines and drop on their own.
    perl -ne '
        if ($skip_until_close) {
            $depth += tr/{//;
            $depth -= tr/}//;
            $skip_until_close = 0 if $depth <= 0;
            next;
        }
        next if /^\/\/ swift-(interface-format-version|compiler-version|module-flags)/;
        next if /^ *\@objc deinit$/;
        next if /^ *\@usableFromInline$/;
        if (/\binternal\b/) {
            my $opens = tr/{//;
            my $closes = tr/}//;
            if ($opens > $closes) {
                $skip_until_close = 1;
                $depth = $opens - $closes;
            }
            next;
        }
        s/\@_hasMissingDesignatedInitializers //g;
        s/\@inlinable //g;
        s/\b(SwiftMocking|Swift|_Concurrency)\.//g;
        print;
    ' "$src" > "$dst"

    echo "  $module → $dst ($(wc -l < "$dst" | tr -d ' ') lines)"
}

echo "Writing interfaces..."
clean_interface "$BUILD_DIR/SwiftMocking.swiftinterface" \
    "$OUT_DIR/SwiftMocking.swiftinterface" "SwiftMocking"
clean_interface "$BUILD_DIR/SwiftMockingTestSupport.swiftinterface" \
    "$OUT_DIR/SwiftMockingTestSupport.swiftinterface" "SwiftMockingTestSupport"

echo "Done."
