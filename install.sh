#!/usr/bin/env bash
# Install the latest evor release.
#
#   curl -fsSL https://evor.live/install.sh | bash
#
# Binaries come from the public release mirror rabin-a/evor-releases (no login
# needed). A GitHub token from EVOR_GITHUB_TOKEN, GH_TOKEN, GITHUB_TOKEN or a
# logged-in `gh` CLI is used when present, e.g. for a private EVOR_REPO.
#
# Options (environment variables):
#   EVOR_VERSION=v0.2.0      install a specific release (default: latest)
#   EVOR_INSTALL_DIR=/path   where to put the binary (default: the directory of
#                            an existing `evor` on PATH, else ~/.local/bin)
#   EVOR_REPO=owner/name     repository to install from
set -euo pipefail

REPO="${EVOR_REPO:-rabin-a/evor-releases}"
VERSION="${EVOR_VERSION:-latest}"

say() { printf '\033[1mevor:\033[0m %s\n' "$*"; }
die() { printf '\033[31mevor: %s\033[0m\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)               TARGET=aarch64-apple-darwin ;;
  Darwin-x86_64)              TARGET=x86_64-apple-darwin ;;
  Linux-x86_64)               TARGET=x86_64-unknown-linux-musl ;;
  Linux-aarch64|Linux-arm64)  TARGET=aarch64-unknown-linux-musl ;;
  *) die "no prebuilt binary for $(uname -s)/$(uname -m); build from source: cargo install --git https://github.com/$REPO" ;;
esac

TOKEN="${EVOR_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
if [ -z "$TOKEN" ] && command -v gh >/dev/null; then
  TOKEN="$(gh auth token 2>/dev/null || true)"
fi

api() { # api <url> <accept> [curl args...]
  local url="$1" accept="$2"; shift 2
  if [ -n "$TOKEN" ]; then
    curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: $accept" -H "X-GitHub-Api-Version: 2022-11-28" "$@" "$url"
  else
    curl -fsSL -H "Accept: $accept" "$@" "$url"
  fi
}

if [ "$VERSION" = latest ]; then
  RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
else
  case "$VERSION" in v*) ;; *) VERSION="v$VERSION" ;; esac
  RELEASE_URL="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
fi

RELEASE="$(api "$RELEASE_URL" application/vnd.github+json)" || {
  [ -z "$TOKEN" ] && die "could not read $REPO releases (no release yet, GitHub rate limit, or a private EVOR_REPO: run 'gh auth login' or set EVOR_GITHUB_TOKEN)"
  die "could not read $RELEASE_URL (no release yet, or the token cannot read $REPO)"
}

# Find an asset's API url by name without needing jq.
asset_url() {
  printf '%s' "$RELEASE" | tr -d '\n' | awk '{ gsub(/},/, "}\n"); print }' \
    | grep "\"name\": *\"$1\"" | grep -o '"url": *"[^"]*/releases/assets/[0-9]*"' \
    | head -1 | sed 's/.*"\(https[^"]*\)"/\1/'
}
TAG="$(printf '%s' "$RELEASE" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
NAME="evor-$TARGET"
BIN_URL="$(asset_url "$NAME")"
SUM_URL="$(asset_url "$NAME.sha256")"
[ -n "$BIN_URL" ] || die "release $TAG has no binary for $TARGET"
[ -n "$SUM_URL" ] || die "release $TAG has no checksum for $TARGET"

if [ -n "${EVOR_INSTALL_DIR:-}" ]; then
  DIR="$EVOR_INSTALL_DIR"
elif existing="$(command -v evor 2>/dev/null)" && [ -w "$(dirname "$existing")" ]; then
  DIR="$(dirname "$existing")"
else
  DIR="$HOME/.local/bin"
fi
mkdir -p "$DIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "downloading evor $TAG ($TARGET)"
api "$BIN_URL" application/octet-stream -o "$TMP/$NAME"
api "$SUM_URL" application/octet-stream -o "$TMP/$NAME.sha256"

EXPECTED="$(awk '{print $1}' "$TMP/$NAME.sha256")"
if command -v sha256sum >/dev/null; then
  ACTUAL="$(sha256sum "$TMP/$NAME" | awk '{print $1}')"
else
  ACTUAL="$(shasum -a 256 "$TMP/$NAME" | awk '{print $1}')"
fi
[ "$EXPECTED" = "$ACTUAL" ] || die "checksum mismatch (expected $EXPECTED, got $ACTUAL)"

chmod 755 "$TMP/$NAME"
mv -f "$TMP/$NAME" "$DIR/evor"
say "installed $("$DIR/evor" --version) to $DIR/evor"

case ":$PATH:" in
  *":$DIR:"*) ;;
  *) say "add $DIR to your PATH, e.g.: echo 'export PATH=\"$DIR:\$PATH\"' >> ~/.zshrc" ;;
esac
say "next: cd into a repository and run 'evor init'. Update later with 'evor update'."
