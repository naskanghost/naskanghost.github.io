#!/bin/sh -e

# Prevent execution if this script was only partially downloaded
{
RC='\033[0m'
RED='\033[0;31m'

# Repo owner/name (permite trocar sem editar o script)
OWNER="${OWNER:-naskanghost}"
REPO="${REPO:-linutil}"

# Function to fetch the latest release tag from the GitHub API
get_latest_release() {
  latest_release=$(curl -s ${GITHUB_API:-https://api.github.com}/repos/${OWNER}/${REPO}/releases |
    grep "tag_name" |
    head -n 1 |
    sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
  if [ -z "$latest_release" ]; then
    printf "%b\n" "Error fetching release data" >&2
    return 1
  fi
  printf "%b\n" "$latest_release"
}

check() {
    exit_code=$1
    message=$2

    if [ "$exit_code" -ne 0 ]; then
        printf "%b\n" "${RED}ERROR: $message${RC}"
        exit 1
    fi
}

addArch() {
    case "${arch}" in
        x86_64);;
        *) url="${url}-${arch}";;
    esac
}

findArch() {
    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) printf "%b\n" "${RED}Unsupported architecture${RC}"; exit 1 ;;
    esac
}

download_latest_release() {
  latest_release=$(get_latest_release || true)
  if [ -n "$latest_release" ]; then
    url="https://github.com/${OWNER}/${REPO}/releases/download/$latest_release/linutil"
  else
    printf "%b\n" 'Unable to determine latest pre-release version.' >&2
    printf "%b\n" "Using latest Full Release"
    url="https://github.com/${OWNER}/${REPO}/releases/latest/download/linutil"
  fi
  addArch
  printf "%b\n" "Using URL: $url"

  TMPFILE=$(mktemp)
  check $? "Creating the temporary file"

  printf "%b\n" "Downloading linutil from $url"
  if curl -fsL "$url" -o "$TMPFILE"; then
    chmod +x "$TMPFILE"
    check $? "Making linutil executable"
    "$TMPFILE" "$@"
    check $? "Executing linutil"
    rm -f "$TMPFILE"
    check $? "Deleting the temporary file"
    return 0
  else
    rm -f "$TMPFILE" >/dev/null 2>&1 || true
    return 1
  fi
}

fallback_clone_and_build() {
  WORKDIR="${XDG_CACHE_HOME:-$HOME/.cache}/linutil-run"
  SRC="${WORKDIR}/src"

  printf "%b\n" "[fallback] Cloning ${OWNER}/${REPO} into ${SRC}"
  rm -rf "$SRC"
  git clone --depth 1 "https://github.com/${OWNER}/${REPO}.git" "$SRC"
  cd "$SRC"

  if [ -x "./target/release/linutil" ]; then
    exec "./target/release/linutil" "$@"
  fi

  if command -v cargo >/dev/null 2>&1; then
    printf "%b\n" "[fallback] Building with cargo (release)"
    cargo build --release
    exec "./target/release/linutil" "$@"
  fi

  printf "%b\n" "${RED}[fallback] cargo not found and no prebuilt binary available.${RC}"
  exit 1
}

# --- main ---
findArch
if ! download_latest_release "$@"; then
  fallback_clone_and_build "$@"
fi
} # End of wrapping
