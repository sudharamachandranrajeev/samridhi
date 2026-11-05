# Samridhi sync server

A [PocketBase](https://pocketbase.io) server (pinned in `pocketbase-version.sh`)
with Samridhi's schema (`pb_migrations/`) and sign-up rule (`pb_hooks/`).
It stores one append-only collection, `sam_changes`: encrypted whole-state
snapshots, one numbered row per push. The server never sees plaintext.

The step-by-step guide — local trial, Docker, HTTPS, sharing a server with
Artha, limits, backups — is **[docs/self-hosting.md](../docs/self-hosting.md)**.

Quick start for development: `scripts/run-local-server.sh` from the repo root.
