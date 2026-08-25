#!/usr/bin/env bash
# Graphical updater for a fedimint guardian, launched from the "Update Guardian"
# icon installed by bootstrap.sh. Fetches the current docker-compose.yaml from
# the installer repo, shows the version change, and recreates the containers.
#
# The compose file pins an exact fedimintd release, so this only ever moves you
# between tagged releases — never onto an untagged branch build.

set -euo pipefail

DEPLOY_DIR="$HOME/fedimintd"
COMPOSE_URL="https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/docker-compose.yaml"
COMPOSE="$DEPLOY_DIR/docker-compose.yaml"

info() { zenity --info --width=420 --title="Update Guardian" --text="$1"; }
die() { zenity --error --width=420 --title="Update Guardian" --text="$1" || true; exit 1; }

# The image line pins the release, so the tag is the version.
version_of() {
    sed -n 's|^ *image: fedimint/fedimintd:\(.*\)$|\1|p' "$1" | head -1
}

if [[ ! -f "$COMPOSE" ]]; then
    die "No guardian deployment found at $DEPLOY_DIR."
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if ! curl -fsSL "$COMPOSE_URL" -o "$tmp"; then
    die "Could not download the latest configuration. Check your internet connection and try again."
fi

current=$(version_of "$COMPOSE")
latest=$(version_of "$tmp")

if [[ -z "$latest" ]]; then
    die "The downloaded configuration looks malformed. Try again later."
fi

if [[ "$current" == "$latest" ]]; then
    info "Your guardian is already running the latest release ($current).

Nothing to do."
    exit 0
fi

zenity --question --width=460 --title="Update Guardian" --ok-label="Update" --cancel-label="Not now" --text="A new fedimintd release is available.

    Installed:  $current
    Available:  $latest

Your guardian will restart, which briefly takes it offline. Your federation
keeps running as long as enough co-guardians stay online, so coordinate the
timing with them before continuing.

Any changes you made to docker-compose.yaml by hand will be replaced." || exit 0

cp "$tmp" "$COMPOSE"

# One authentication prompt for the whole privileged step.
if ! pkexec /usr/bin/env DEPLOY_DIR="$DEPLOY_DIR" bash -c '
        set -euo pipefail
        cd "$DEPLOY_DIR"
        docker compose pull
        docker compose up -d
    ' 2>&1 | zenity --progress --pulsate --auto-close --no-cancel --width=460 \
        --title="Update Guardian" --text="Downloading and restarting…"; then
    die "The update did not complete. Your guardian may still be running the previous release.

Open the log viewer at http://127.0.0.1:8080 to see what happened, then try again."
fi

info "Your guardian is now running fedimintd $latest."
