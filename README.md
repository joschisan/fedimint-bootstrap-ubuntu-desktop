One-shot installer for a [Fedimint](https://github.com/fedimint/fedimint) guardian
on a fresh Ubuntu desktop.

```bash
curl -fsSL https://raw.githubusercontent.com/joschisan/fedimint-bootstrap-ubuntu-desktop/main/bootstrap.sh | bash
```

## What it does

1. Install Docker (if missing)
2. Write the guardian compose, updater and log viewer into `~/fedimint`
3. Pull and start fedimintd + a bundled, fully validating Bitcoin Core node (~1TB)
4. Wait for the Web UI to come up at `http://127.0.0.1:8175`
5. Pin Dashboard, Logs and Update shortcuts to the dock
6. Install Signal Desktop for exchanging setup codes with co-guardians

The installer is fully self-contained — the compose file, updater and log
viewer are embedded in the script. It is safe to re-run at any time;
guardian state lives in Docker volumes a re-run never touches.
