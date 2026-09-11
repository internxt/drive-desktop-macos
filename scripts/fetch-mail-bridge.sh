#!/usr/bin/env bash
#
# Puts the mail-bridge daemon binary into the app bundle's staging directory.
#
# Two sources, one verification/extraction path, so switching to published
# releases later is a flag change and nothing else:
#
#   --from-local <repo>     build the daemon from a checkout (what we do today,
#                           since the daemon has no published releases yet)
#   --from-release <ver>    download the pinned release tarball and verify it
#                           against the manifest's sha256
#
# Switching to --from-release also lets the daemon checkout and Go setup steps be
# deleted from the three GitHub workflows: nothing is compiled from source any more.
#
# Both end up producing a tarball whose single root entry is `mail-bridge`,
# exactly the artifact contract in the daemon's release/manifest.schema.json.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$REPO_ROOT/InternxtDesktop/MailBridgeResources"
# Created when we pin the first release: the daemon requires an exact version and
# forbids tracking latest, so --from-release verifies the download against it.
PIN_FILE="$REPO_ROOT/mail-bridge.pin.json"
BINARY_NAME="mail-bridge"
RELEASE_BASE_URL="https://github.com/internxt/mail-bridge-desktop/releases/download"

MODE=""
SOURCE=""

log()  { printf '[mail-bridge] %s\n' "$*" >&2; }
fail() { printf '[mail-bridge] error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'
    exit 64
}

while [ $# -gt 0 ]; do
    case "$1" in
        --from-local)   MODE="local";   SOURCE="${2:-}"; shift 2 ;;
        --from-release) MODE="release"; SOURCE="${2:-}"; shift 2 ;;
        --dest)         DEST_DIR="${2:-}"; shift 2 ;;
        --pin)          PIN_FILE="${2:-}"; shift 2 ;;
        -h|--help)      usage ;;
        *)              fail "unknown argument: $1" ;;
    esac
done

[ -n "$MODE" ]   || usage
[ -n "$SOURCE" ] || fail "--from-$MODE needs a value"

# ---------------------------------------------------------------- helpers

sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# The daemon is CGO-only (mattn/go-sqlite3 via Gluon), so CGO_ENABLED=0 will not
# build and cross-compiling from a non-macOS host is out. On a Mac with the
# Command Line Tools both slices build fine.
build_universal() {
    local repo="$1" out="$2" work
    command -v go >/dev/null || fail "go is not installed (needed by --from-local)"
    [ -d "$repo/cmd/bridge" ] || fail "$repo does not look like mail-bridge-desktop"

    work="$(mktemp -d)"
    trap 'rm -rf "$work"' RETURN

    log "building arm64…"
    ( cd "$repo" && CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
        go build -trimpath -ldflags='-s -w' -o "$work/arm64" ./cmd/bridge )

    log "building amd64…"
    ( cd "$repo" && CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 CC="clang -arch x86_64" \
        go build -trimpath -ldflags='-s -w' -o "$work/amd64" ./cmd/bridge )

    log "lipo → universal"
    lipo -create "$work/arm64" "$work/amd64" -output "$out"
    chmod 0755 "$out"
}

download_release() {
    local version="$1" out="$2" arch tarball url work expected actual
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' RETURN

    # The daemon publishes one tarball per arch; we lipo them back together.
    for arch in arm64 amd64; do
        tarball="${BINARY_NAME}_${version}_darwin_${arch}.tar.gz"
        url="$RELEASE_BASE_URL/v${version}/${tarball}"
        log "downloading $tarball"
        curl -fsSL "$url" -o "$work/$tarball" \
            || fail "could not download $url (is darwin/$arch published for v$version?)"

        expected="$(pin_value "sha256_darwin_${arch}")"
        actual="$(sha256_of "$work/$tarball")"
        [ -n "$expected" ] || fail "no sha256_darwin_${arch} in $PIN_FILE — create it when pinning a release"
        [ "$expected" = "$actual" ] \
            || fail "sha256 mismatch for $tarball: pinned $expected, got $actual"

        tar -xzf "$work/$tarball" -C "$work" "$BINARY_NAME"
        mv "$work/$BINARY_NAME" "$work/$arch"
    done

    lipo -create "$work/arm64" "$work/amd64" -output "$out"
    chmod 0755 "$out"
}

pin_value() {
    [ -f "$PIN_FILE" ] || return 0
    /usr/bin/python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))
except Exception:
    print("")' "$PIN_FILE" "$1"
}

# ---------------------------------------------------------------- main

mkdir -p "$DEST_DIR"
TARGET="$DEST_DIR/$BINARY_NAME"
STAMP="$DEST_DIR/.stamp"

case "$MODE" in
    local)
        SOURCE="$(cd "$SOURCE" && pwd)"
        # Idempotent: rebuilding on every Xcode build would be painful, so skip
        # when the checkout has not moved. A dirty tree always rebuilds.
        # Hash HEAD plus the contents of anything modified or untracked, so a
        # dirty checkout still skips the rebuild while it has not actually
        # changed. A timestamp here would rebuild on every single Xcode build.
        revision="$(
            {
                git -C "$SOURCE" rev-parse HEAD 2>/dev/null || echo unknown
                git -C "$SOURCE" ls-files -mo --exclude-standard -z 2>/dev/null \
                    | xargs -0 -I{} shasum -a 256 "$SOURCE/{}" 2>/dev/null
            } | shasum -a 256 | awk '{print $1}'
        )"
        want="local:$revision"
        if [ -x "$TARGET" ] && [ "$(cat "$STAMP" 2>/dev/null || true)" = "$want" ]; then
            log "up to date ($revision)"
            exit 0
        fi
        build_universal "$SOURCE" "$TARGET"
        printf '%s' "$want" > "$STAMP"
        ;;
    release)
        want="release:$SOURCE"
        if [ -x "$TARGET" ] && [ "$(cat "$STAMP" 2>/dev/null || true)" = "$want" ]; then
            log "up to date (v$SOURCE)"
            exit 0
        fi
        download_release "$SOURCE" "$TARGET"
        printf '%s' "$want" > "$STAMP"
        ;;
esac

log "installed $TARGET ($(lipo -archs "$TARGET" 2>/dev/null || echo '?'))"
