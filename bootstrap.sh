#!/usr/bin/env bash
# One-shot installer for a fedimint guardian on a fresh Ubuntu desktop.
#
# Installs Docker (if missing), brings up fedimintd + a bundled, fully
# validating bitcoind, opens the Web UI in a browser, installs Signal Desktop
# for exchanging setup codes during the federation ceremony, and pins
# Dashboard, Logs and Update shortcuts to the dock. Nothing here needs a
# terminal afterwards.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/bootstrap.sh | bash

set -euo pipefail

DEPLOY_DIR="$HOME/fedimintd"
COMPOSE_URL="https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/docker-compose.yaml"
UPDATE_URL="https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/update.sh"
UI_URL="http://127.0.0.1:8175"
LOGS_URL="http://127.0.0.1:8080"

confirm() {
    if [[ "${AUTO_YES:-}" == "1" ]]; then
        return 0
    fi
    read -rp "$1 [y/N] " reply </dev/tty
    [[ "$reply" =~ ^[Yy]$ ]]
}

pin_to_dock() {
    local desktop_id="$1" favs new
    favs=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo '[]')
    if [[ "$favs" == *"$desktop_id"* ]]; then
        return 0
    fi
    if [[ "$favs" == "[]" ]]; then
        new="['$desktop_id']"
    else
        new="${favs%]}, '$desktop_id']"
    fi
    gsettings set org.gnome.shell favorite-apps "$new" 2>/dev/null || true
}

install_launcher() {
    local id="$1" name="$2" comment="$3" icon="$4" exec_line="$5"
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/$id" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$exec_line
Icon=$icon
Terminal=false
Categories=System;
DESKTOP
    pin_to_dock "$id"
}

ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    echo "Unsupported architecture: $ARCH. This installer targets Ubuntu amd64 or arm64." >&2
    exit 1
fi

DISTRO_ID="unknown"
DISTRO_VERSION="unknown"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
fi
if [[ "$DISTRO_ID" != "ubuntu" || "$DISTRO_VERSION" != "26.04" ]]; then
    echo "This installer requires Ubuntu 26.04 LTS desktop. You appear to be running $DISTRO_ID $DISTRO_VERSION." >&2
    exit 1
fi

if [[ -e "$DEPLOY_DIR" ]]; then
    echo "Existing deployment found at $DEPLOY_DIR. Aborting." >&2
    exit 1
fi

# A full, unpruned bitcoind needs ~1TB, plus headroom for fedimintd's own
# database and future chain growth.
AVAIL_GB=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
if [[ "$AVAIL_GB" -lt 1200 ]]; then
    echo "Only ${AVAIL_GB}GB free on $HOME. A full Bitcoin Core node needs ~1TB, and 1.2TB is recommended." >&2
    confirm "Continue anyway?" || { echo "Aborted."; exit 0; }
fi

cat <<EOF
This installer will set up a fedimint guardian on this machine:

  1. Install Docker (if missing)
  2. Download the guardian compose into $DEPLOY_DIR
  3. Start fedimintd + a bundled, fully validating Bitcoin Core node (~1TB)
  4. Wait for the Web UI to come up at $UI_URL
  5. Install Signal Desktop for exchanging setup codes with co-guardians
  6. Pin Dashboard, Logs and Update shortcuts to the dock

Your guardian uses this node and nothing else for chain data, so it is not
ready until the node has synced the Bitcoin blockchain — a day or more. Do not
run the setup ceremony before then. The command to check is printed at the end.

EOF

confirm "Continue?" || { echo "Aborted."; exit 0; }

sudo -v

if ! command -v docker >/dev/null; then
    echo "==> Installing Docker"
    curl -fsSL https://get.docker.com | sh
fi

sudo usermod -aG docker "$USER"

echo "==> Preparing $DEPLOY_DIR"
mkdir "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

echo "==> Downloading docker-compose.yaml"
curl -fsSL -O "$COMPOSE_URL"

echo "==> Downloading update.sh"
curl -fsSL -O "$UPDATE_URL"
chmod +x update.sh

echo "==> Adding dock icons"
install_launcher fedimint-guardian.desktop \
    "Dashboard" "Open the guardian Web UI" \
    web-browser "xdg-open $UI_URL"
install_launcher fedimint-guardian-logs.desktop \
    "Logs" "View the guardian log output" \
    utilities-system-monitor "xdg-open $LOGS_URL"
install_launcher fedimint-guardian-update.desktop \
    "Update" "Install the latest guardian release" \
    system-software-update "$DEPLOY_DIR/update.sh"

echo "==> Starting guardian"
sudo docker compose up -d

echo "==> Waiting for Web UI at $UI_URL"
for _ in $(seq 60); do
    if curl -sf "$UI_URL" >/dev/null; then
        break
    fi
    sleep 1
done

if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    echo "==> Opening $UI_URL"
    xdg-open "$UI_URL" >/dev/null 2>&1 || true
fi

# Signal Desktop ships amd64 debs only.
if [[ "$ARCH" == "amd64" ]] && ! command -v signal-desktop >/dev/null; then
    echo "==> Installing Signal Desktop"
    curl -fsSL https://updates.signal.org/desktop/apt/keys.asc \
        | gpg --dearmor \
        | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg >/dev/null
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' \
        | sudo tee /etc/apt/sources.list.d/signal-xenial.list >/dev/null
    sudo apt update
    sudo apt install -y signal-desktop

    echo "==> Pinning Signal Desktop to the dock"
    pin_to_dock signal-desktop.desktop
fi

cat <<EOF

Guardian is running.

  Web UI:   $UI_URL
  Logs UI:  $LOGS_URL
  Compose:  $DEPLOY_DIR/docker-compose.yaml
  Logs:     sudo docker compose -f $DEPLOY_DIR/docker-compose.yaml logs -f

Bitcoin Core is now syncing. Your guardian has no other chain data source, so
wait for this to report "initialblockdownload": false before going further:

  sudo docker compose -f $DEPLOY_DIR/docker-compose.yaml exec bitcoind \\
      bitcoin-cli -rpcuser=bitcoin -rpcpassword=bitcoin getblockchaininfo

Next steps, once it is synced:
  1. Click "Dashboard" in the dock to open the Web UI.
  2. Open Signal and coordinate setup-code exchange with your co-guardians.

The dock also has "Logs" for log output and "Update" for installing future
releases.
EOF
