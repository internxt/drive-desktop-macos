#!/usr/bin/env bash
#
# Puts the mail-bridge daemon binary into the app bundle's staging directory.
#
# Two sources, one verification/extraction path, so switching to published
# releases later is a flag change and nothing else:
#
#   --from-local <repo>     build the daemon from a checkout (what we do today,
#                           since the daemon has no published releases yet)
#   --from-release <ver>    download the published release archive and verify it
#                           against the sha256 GitHub records for that asset
#
# Switching to --from-release also lets the daemon checkout and Go setup steps be
# deleted from the three GitHub workflows: nothing is compiled from source any more.
#
# Both end up producing a tarball whose single root entry is `mail-bridge`,
# exactly the artifact contract documented in the daemon's README.

set -euo pipefail

# Xcode gives run script phases a minimal PATH that excludes Homebrew, which is where
# Go normally lives. Without this the build fails with "go is not installed" even
# though `go` works fine from a terminal.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/local/go/bin:${HOME}/go/bin"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$REPO_ROOT/InternxtDesktop/MailBridgeResources"
BINARY_NAME="mail-bridge"
RELEASE_API_URL="https://api.github.com/repos/internxt/mail-bridge-desktop/releases"

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
    command -v go >/dev/null \
        || fail "go not found on PATH (looked in $PATH) — needed by --from-local"
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

# The daemon publishes one macOS archive holding a binary for both kinds of Mac. GitHub
# records a sha256 for every asset it serves, so the download is checked against what
# the release itself reports rather than against a number copied into this repo.
download_release() {
    local version="$1" out="$2" work asset url expected actual

    work="$(mktemp -d)"
    trap 'rm -rf "$work"' RETURN

    asset="${BINARY_NAME}_${version}_darwin_universal.tar.gz"

    log "asking GitHub about v$version"
    api "$RELEASE_API_URL/tags/v${version}" "$work/release.json" \
        || fail "could not read release v$version (is it published?)"

    # The assets are asked for separately. The release payload carries a copy of them,
    # but that copy is served stale: minutes after a release is published it still
    # comes back empty, which is indistinguishable from a release that was never built.
    api "$(release_field "$work/release.json" assets_url)?per_page=100" "$work/assets.json" \
        || fail "could not list the assets of v$version"

    url="$(asset_field "$work/assets.json" "$asset" url)"
    expected="$(asset_field "$work/assets.json" "$asset" sha256)"
    [ -n "$url" ] || fail "release v$version has no $asset"
    [ -n "$expected" ] || fail "GitHub reports no sha256 for $asset"

    log "downloading $asset"
    curl -fsSL "$url" -o "$work/$asset" || fail "could not download $url"

    actual="$(sha256_of "$work/$asset")"
    [ "$expected" = "$actual" ] \
        || fail "sha256 mismatch for $asset: GitHub says $expected, got $actual"

    tar -xzf "$work/$asset" -C "$work" "$BINARY_NAME"
    mv "$work/$BINARY_NAME" "$out"
    chmod 0755 "$out"

    # A binary that only runs on the machine that fetched it would pass every check
    # above and fail on the other kind of Mac, where nobody would connect it to this.
    lipo -archs "$out" | grep -q x86_64 || fail "$asset carries no x86_64 slice"
    lipo -archs "$out" | grep -q arm64  || fail "$asset carries no arm64 slice"
}

api() {
    curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$1" -o "$2"
}

release_field() {
    /usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$1" "$2"
}

# Reads one field of a named asset out of GitHub's asset listing.
asset_field() {
    /usr/bin/python3 -c 'import json,sys
listing, wanted, field = sys.argv[1], sys.argv[2], sys.argv[3]
for asset in json.load(open(listing)):
    if asset.get("name") != wanted:
        continue
    if field == "url":
        print(asset.get("browser_download_url", ""))
    else:
        print((asset.get("digest") or "").removeprefix("sha256:"))
    break' "$1" "$2" "$3"
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
