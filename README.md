# fedimint-bootstrap-ubuntu-desktop

One-shot installer for a [Fedimint](https://github.com/fedimint/fedimint) guardian
on a fresh Ubuntu desktop.

```bash
curl -fsSL https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/bootstrap.sh | bash
```

## What it does

1. Installs Docker if missing.
2. Writes `docker-compose.yaml` into `~/fedimintd` and starts it.
3. Waits for the Web UI, then installs Signal Desktop for exchanging setup
   codes with your co-guardians during the DKG ceremony.
4. Pins three icons to the dock:

| Icon | Opens |
| --- | --- |
| **Dashboard** | the Web UI at `127.0.0.1:8175` |
| **Logs** | the log viewer at `127.0.0.1:8080` |
| **Update** | the updater described below |

Nothing after step 1 needs a terminal.

| Service | Address | Exposure |
| --- | --- | --- |
| fedimintd p2p + api | `0.0.0.0:8173/udp`, `0.0.0.0:8174/udp` | public — must be reachable by peers |
| fedimintd Web UI | `127.0.0.1:8175` | loopback — this machine only |
| Log viewer (dozzle) | `127.0.0.1:8080` | loopback — this machine only |
| bitcoind RPC | `127.0.0.1:8332` | loopback — this machine only |

All services run with `network_mode: host`. fedimintd's p2p and api are iroh
(UDP), and bridge networking would stack Docker's NAT on top of your router's,
leaving iroh two layers to punch through instead of one. The tradeoff is that
each service binds its own address rather than being contained by a published
port, so the loopback binds above are the only thing keeping the two UIs and the
Bitcoin RPC off your LAN — take care when editing them.

## Requirements

- Ubuntu 26.04 LTS desktop, amd64 or arm64
- ~1.2TB free disk — ~1TB for the Bitcoin node, the rest headroom
- A publicly reachable UDP path for ports 8173 and 8174

## Bitcoin backend

This ships a bundled Bitcoin Core node and points fedimintd at it exclusively.
There is no third-party fallback: your guardian validates the chain itself, and
gets chain data from nowhere else.

**The node is not pruned.** It keeps the full chain (~1TB), so it can serve
historical blocks — which a federation restored from backup needs, and a pruned
node cannot provide.

## Updating

Click **Update** in the dock. It runs `docker compose pull` and recreates any
containers whose image changed — no password prompt, no confirmation. The
compose file is written once at install and never touched again; what an
update means is decided entirely by where the image tags point.

If an update is found, the restart briefly takes the guardian offline. The
federation keeps running as long as enough co-guardians stay up, so agree the
timing with them first.

## Versions

The compose floats on published tags rather than pinning exact versions:
`fedimintd` tracks its release series (`releases-v0.11`, so patch releases
arrive via the Update button), and `bitcoin/bitcoin` and `dozzle` track
`latest`. Moving fedimintd to a new release series is a one-line edit to the
installed `~/fedimintd/docker-compose.yaml`.
