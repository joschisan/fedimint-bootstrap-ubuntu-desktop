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
| **Guardian** | the Web UI at `127.0.0.1:8175` |
| **Guardian Logs** | the log viewer at `127.0.0.1:8080` |
| **Update Guardian** | the updater described below |

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

- Ubuntu (tested on 26.04 LTS desktop), amd64 or arm64
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

Click **Update Guardian** in the dock. It fetches the current
`docker-compose.yaml` from this repo and compares it to the installed one. If
they differ at all, the whole file is replaced and the containers are recreated;
if they match, there is nothing to do. There is one password prompt for the
privileged step.

Because the compose file pins an exact release, this only ever moves a guardian
between tagged releases — never onto an untagged branch build. Editing the file
in this repo is what publishes an update.

The restart briefly takes the guardian offline. The federation keeps running as
long as enough co-guardians stay up, so agree the timing with them first.

## Versions

Images are pinned. Current: `fedimintd v0.11.2`, `bitcoin 31.0`, `dozzle v10.7`.
