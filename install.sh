#!/bin/sh
# Install the blaise CLI: the latest release, or the version given as an argument.
#
#   curl -fsSL https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.sh | sh -s -- 2026.10.2
#
# BLAISE_INSTALL_DIR chooses where blaise is installed (default: ~/.local/bin).
# BLAISE_RELEASE_BASE_URL overrides where releases are downloaded from (used by the tests).
set -eu

BASE_URL="${BLAISE_RELEASE_BASE_URL:-https://github.com/BlaiseAgent/cli/releases}"
INSTALL_DIR="${BLAISE_INSTALL_DIR:-$HOME/.local/bin}"

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

usage() {
  say "Usage: install.sh [--version] [VERSION]"
  say ""
  say "Installs the blaise CLI into \$BLAISE_INSTALL_DIR (default ~/.local/bin)."
  say "Without VERSION the latest release is installed, for example: install.sh 2026.10.2"
}

version=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -v | --version)
      [ "$#" -ge 2 ] || fail "--version needs a value"
      version="$2"
      shift 2
      ;;
    -*)
      fail "unknown option $1 (see --help)"
      ;;
    *)
      version="$1"
      shift
      ;;
  esac
done

case "$BASE_URL" in
  *BlaiseAgent/cli*)
    fail "this copy of the script was not published by a release; set BLAISE_RELEASE_BASE_URL"
    ;;
esac

# Accept 2026.10.2 and v2026.10.2.
version="${version#v}"
case "$version" in
  *[!0-9.]*) fail "\"$version\" is not a version such as 2026.10.2" ;;
esac

# --- platform ---------------------------------------------------------------

uname_s="$(uname -s)"
uname_m="$(uname -m)"

case "$uname_s" in
  Darwin) os="darwin" ;;
  Linux) os="linux" ;;
  MINGW* | MSYS* | CYGWIN*)
    fail "this is Windows: use install.ps1 instead (see the README of this repository)"
    ;;
  *) fail "no blaise binary for $uname_s on $uname_m; see https://askblaise.com/docs/cli" ;;
esac

case "$uname_m" in
  arm64 | aarch64) arch="arm64" ;;
  x86_64 | amd64) arch="x64" ;;
  *) fail "no blaise binary for $uname_s on $uname_m; see https://askblaise.com/docs/cli" ;;
esac

# A shell running under Rosetta reports x86_64 on an Apple silicon machine.
if [ "$os" = "darwin" ] && [ "$arch" = "x64" ]; then
  if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = "1" ]; then
    arch="arm64"
  fi
fi

# Linux has a binary per C library: Alpine and other musl systems get the -musl one.
libc=""
if [ "$os" = "linux" ]; then
  for loader in /lib/ld-musl-*; do
    if [ -e "$loader" ]; then
      libc="-musl"
    fi
  done
  # musl's ldd answers --version on stderr, with an error status.
  case "$(ldd --version 2>&1 || true)" in
    *musl*) libc="-musl" ;;
  esac
fi

# --- helpers ----------------------------------------------------------------

have() {
  command -v "$1" >/dev/null 2>&1
}

download() {
  if have curl; then
    curl -fsSL --retry 3 -o "$2" "$1" || fail "could not download $1"
  elif have wget; then
    wget -q -O "$2" "$1" || fail "could not download $1"
  else
    fail "curl or wget is required"
  fi
}

# The URL the latest release redirects to, which ends in /tag/v<version>.
latest_location() {
  if have curl; then
    curl -fsS -o /dev/null -w '%{redirect_url}' "$BASE_URL/latest"
  elif have wget; then
    wget --max-redirect=0 -S -O /dev/null "$BASE_URL/latest" 2>&1 | sed -n 's/^ *[Ll]ocation: *//p' | head -n 1 | tr -d '\r'
  else
    fail "curl or wget is required"
  fi
}

sha256_of() {
  if have sha256sum; then
    sha256sum "$1" | cut -d ' ' -f 1
  elif have shasum; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  elif have openssl; then
    openssl dgst -sha256 "$1" | sed 's/^.*= *//'
  else
    fail "sha256sum, shasum or openssl is required to verify the download"
  fi
}

# --- version ----------------------------------------------------------------

if [ -z "$version" ]; then
  location="$(latest_location)" || fail "could not find the latest release at $BASE_URL"
  case "$location" in
    */tag/v*) version="${location##*/tag/v}" ;;
    *) fail "could not find the latest release at $BASE_URL" ;;
  esac
fi

asset="blaise-$version-$os-$arch$libc.tar.gz"
release_url="$BASE_URL/download/v$version"

# --- download and verify ----------------------------------------------------

tmp="$(mktemp -d "${TMPDIR:-/tmp}/blaise-install.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

say "Installing blaise $version for $os-$arch$libc"
download "$release_url/checksums.txt" "$tmp/checksums.txt"
download "$release_url/$asset" "$tmp/$asset"

expected="$(awk -v name="$asset" '$2 == name || $2 == "*" name { print $1 }' "$tmp/checksums.txt")"
[ -n "$expected" ] || fail "checksums.txt has no entry for $asset"
actual="$(sha256_of "$tmp/$asset")"
if [ "$expected" != "$actual" ]; then
  fail "checksum mismatch for $asset (expected $expected, got $actual); nothing was installed"
fi

# --- install ----------------------------------------------------------------

mkdir "$tmp/extract"
tar -xzf "$tmp/$asset" -C "$tmp/extract" || fail "could not unpack $asset"
[ -f "$tmp/extract/blaise" ] || fail "$asset does not contain the blaise binary"

mkdir -p "$INSTALL_DIR"
# Copy under a temporary name and rename, so that a running blaise is replaced atomically.
cp "$tmp/extract/blaise" "$INSTALL_DIR/.blaise.$$"
chmod 755 "$INSTALL_DIR/.blaise.$$"
mv -f "$INSTALL_DIR/.blaise.$$" "$INSTALL_DIR/blaise"

say "Installed blaise $version to $INSTALL_DIR/blaise"
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    say ""
    say "$INSTALL_DIR is not on your PATH. Add it, for example:"
    say "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac
