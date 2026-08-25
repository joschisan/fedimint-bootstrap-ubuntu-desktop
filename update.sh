#!/usr/bin/env bash
# Graphical updater for a fedimint guardian, launched from the "Update Guardian"
# icon installed by bootstrap.sh. Fetches the current docker-compose.yaml from
# the installer repo and, if it differs from the installed one at all, replaces
# it and recreates the containers.

set -euo pipefail

DEPLOY_DIR="$HOME/fedimintd"
COMPOSE_URL="https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/docker-compose.yaml"
COMPOSE="$DEPLOY_DIR/docker-compose.yaml"

info() { zenity --info --width=420 --title="Update Guardian" --text="$1"; }
die() { zenity --error --width=420 --title="Update Guardian" --text="$1" || true; exit 1; }

if [[ ! -f "$COMPOSE" ]]; then
    die "No guardian deployment found at $DEPLOY_DIR."
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if ! curl -fsSL "$COMPOSE_URL" -o "$tmp"; then
    die "Could not download the latest configuration. Check your internet connection and try again."
fi

if cmp -s "$COMPOSE" "$tmp"; then
    info "Your guardian is already up to date.

Nothing to do."
    exit 0
fi

zenity --question --width=460 --title="Update Guardian" --ok-label="Update" --cancel-label="Not now" --text="An update is available.

Your guardian will restart, which briefly takes it offline. Your federation
keeps running as long as enough co-guardians stay online, so coordinate the
timing with them before continuing.

Any changes you made to docker-compose.yaml by hand will be replaced." || exit 0

# One authentication prompt for the whole privileged step. The new compose is
# only moved into place once the pull succeeds, so a failed or malformed
# download leaves the installed version running and the next click retries.
if ! pkexec /usr/bin/env DEPLOY_DIR="$DEPLOY_DIR" NEW_COMPOSE="$tmp" bash -c '
        set -euo pipefail
        cd "$DEPLOY_DIR"
        install -m 0644 "$NEW_COMPOSE" docker-compose.yaml.new
        docker compose -f docker-compose.yaml.new pull
        mv docker-compose.yaml.new docker-compose.yaml
        docker compose up -d
    ' 2>&1 | zenity --progress --pulsate --auto-close --no-cancel --width=460 \
        --title="Update Guardian" --text="Downloading and restarting…"; then
    die "The update did not complete. Your guardian may still be running the previous release.

Open the log viewer at http://127.0.0.1:8080 to see what happened, then try again."
fi

info "Your guardian has been updated."
