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

| Service | Address | Exposure |
| --- | --- | --- |
| fedimintd p2p + api | `:8173/udp`, `:8174/udp` | public — must be reachable by peers |
| fedimintd Web UI | `127.0.0.1:8175` | loopback — this machine only |
| Log viewer (dozzle) | `127.0.0.1:8080` | loopback — this machine only |
| bitcoind RPC | docker network only | not published |

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

## Versions

Images are pinned. Current: `fedimintd v0.11.2`, `bitcoin 31.0`, `dozzle v10.7`.
