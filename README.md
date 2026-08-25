# fedimint-bootstrap-ubuntu-desktop

One-shot installer for a [Fedimint](https://github.com/fedimint/fedimint) guardian
on a fresh Ubuntu desktop.

```bash
curl -fsSL https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/bootstrap.sh | bash
```

## What it does

1. Installs Docker if missing.
2. Writes `docker-compose.yaml` into `~/fedimint-guardian` and starts it.
3. Waits for the Web UI, then installs Signal Desktop for exchanging setup
   codes with your co-guardians during the DKG ceremony.

| Service | Address | Exposure |
| --- | --- | --- |
| fedimintd p2p + api | `:8173/udp`, `:8174/udp` | public — must be reachable by peers |
| fedimintd Web UI | `127.0.0.1:8175` | loopback |
| Log viewer (dozzle) | `127.0.0.1:8000` | loopback |
| bitcoind RPC | docker network only | not published |

To reach the UIs from another machine:

```bash
ssh -NL 8175:127.0.0.1:8175 -L 8000:127.0.0.1:8000 <your-host>
```

## Requirements

- Ubuntu (tested on 26.04 LTS desktop), amd64 or arm64
- ~80GB free disk — ~50GB for the pruned Bitcoin node, the rest headroom
- A publicly reachable UDP path for ports 8173 and 8174

## Bitcoin backend

This ships a bundled Bitcoin Core node and points fedimintd at it exclusively.
There is no third-party fallback: your guardian validates the chain itself, and
gets chain data from nowhere else.

**It is not ready until that node has synced**, which takes a day or more. Do
not run the setup ceremony before then. Check with:

```bash
cd ~/fedimint-guardian
sudo docker compose exec bitcoind bitcoin-cli -datadir=/data getblockchaininfo
# wait for "initialblockdownload": false
```

**The node is pruned** (`-prune=50000`, ~50GB rather than ~1TB). A newly created
federation only ever asks for recent blocks, so this is safe for the case this
installer covers. It is *not* safe if you later point an older, restored
federation at this node — it may need blocks that have been pruned away. Drop
the `-prune` flag and resync from scratch if you need that.

## Notes on the log viewer

Dozzle mounts `/var/run/docker.sock`. It is read-only and bound to loopback, but
socket access is effectively host root — anyone who can reach port 8000 or
compromise that container controls the host. Delete the `dozzle` service from
the compose if you would rather use `docker compose logs -f`.

## Versions

Images are pinned. Current: `fedimintd v0.11.2`, `bitcoin 31.0`, `dozzle v10.7`.
