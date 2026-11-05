# Self-hosting Samridhi sync

Sync is optional. Samridhi works fully offline; turn this on only if you want
the same plan on several devices. Everything is encrypted on your device
before upload — the server stores ciphertext only.

## What is stored where

| Secret | Where it lives | What it protects |
| --- | --- | --- |
| **Sync passphrase** | In your head / password manager. Asked at each push/pull, never stored, never sent. | Your data (Argon2id → XChaCha20-Poly1305). If lost, synced data is unrecoverable. |
| **Account password** | Server (hashed by PocketBase) and your device's keychain. | Access to the encrypted blobs. |
| **Invite code** | `server/.env`. | Who may create an account on your server. |

A copy of the server's data reveals your account e-mail and when you synced,
not any holdings, goals or amounts.

## How sync behaves

Each push uploads one encrypted snapshot of all your data and gets the next
number (#1, #2, …). Two devices cannot both write #5: the server's unique
`(owner, seq)` index rejects the second. Samridhi then tells you and asks
which side wins — it never merges silently.

* **Push** is refused if the server has a newer snapshot from another device
  (you may choose to overwrite it).
* **Pull** is refused if this device has changes it never pushed (you may
  choose to replace them).
* Old snapshots stay on the server (append-only). Prune them as superuser if
  the database grows.

Settings, the app-lock PIN and AI keys are per-device and never synced.

## Option A — try it on this computer (Linux/macOS shell)

```sh
scripts/run-local-server.sh        # http://127.0.0.1:8090, admin UI at /_/
```

First run downloads the pinned PocketBase (SHA-256 verified) and writes
`server/.env` (mode 600, git-ignored) with an invite code and superuser
password. In Samridhi: **Settings → Sync**, server `http://127.0.0.1:8090`,
your e-mail and a password, the invite code, then **Create account**, then
**Push**.

To let a phone on your home Wi-Fi sync: `SAMRIDHI_PB_HOST=0.0.0.0
scripts/run-local-server.sh`, then use `http://<this-computer-ip>:8090` on the
phone.

Plain `http://` is accepted by the app only for loopback, private ranges
(10/8, 172.16/12, 192.168/16), Tailscale (100.64/10) and `.local` names.
Every other server must be `https://`.

## Option B — a server that is always on (Docker)

1. Create the invite code (12+ characters, otherwise nobody can sign up):

   ```sh
   echo "SAMRIDHI_SIGNUP_CODE=$(openssl rand -base64 24)" > server/.env
   chmod 600 server/.env
   ```

2. Start it (non-root, read-only filesystem, 127.0.0.1 only):

   ```sh
   cd server && docker compose up -d --build
   docker compose exec samridhi-sync /pb/pocketbase superuser upsert you@example.com 'a long password' --dir=/pb/pb_data
   ```

3. Put HTTPS in front, e.g. [Caddy](https://caddyserver.com):

   ```caddyfile
   sync.example.com {
   	reverse_proxy 127.0.0.1:8090
   }
   ```

   or keep it inside a Tailscale network and use `http://100.x.y.z:8090`.

4. In the admin UI (`https://sync.example.com/_/`) → **Settings**: set the
   Application URL; add `X-Forwarded-For` under *Trusted proxy* (so rate
   limits are per client, not per proxy); add SMTP if you want password-reset
   e-mails.

5. In Samridhi on each device: **Settings → Sync**, enter the URL, e-mail,
   account password; on the first device give the invite code and **Create
   account**. Then **Push** (first device) and **Pull** (others) using the
   *same* sync passphrase.

## Sharing a server with Artha

Samridhi's collection is `sam_changes`, separate from Artha's. To host both
on one PocketBase:

1. Copy `server/pb_migrations/1793000000_samridhi_sync.js` into Artha's
   `pb_migrations/` (it only adds `sam_changes` and appends rate-limit rules).
2. Do **not** copy `pb_hooks/accounts.pb.js` — Artha's hook (invite code
   `ARTHA_SIGNUP_CODE`) then governs sign-up for the shared `users` table.
3. Use the same account on both apps.

Samridhi reads Artha's data only through its own export/backup flow; it never
writes to Artha's collections or ledger.

## Limits built in

| What | Limit (per client IP) |
| --- | --- |
| Sign-in attempts (`*:auth`) | 10 per minute |
| Sign-ups (`users:create`) | 5 per hour |
| Snapshot uploads (`sam_changes:create`, signed in) | 30 per 10 s |
| Any API call | 300 per 10 s |

Batch requests are off. Users can see only their own records. A snapshot is
capped at 2 MB of ciphertext.

## Backups and upgrades

* Back up the `pb_data` volume, or use the admin UI's **Settings → Backups**.
* Independently of the server, **Settings → Backup & restore** in the app
  exports a passphrase-encrypted file that restores on any device.
* To upgrade PocketBase, update `server/pocketbase-version.sh` (version and
  both checksums from the release's `checksums.txt`) after reading its
  changelog, then `docker compose up -d --build`.

## Status of this guide

The server files and the client sync logic are covered by unit tests with an
in-memory server (`test/sync/`), and the shell script is syntax-checked. A
full live test against a running PocketBase has **not** been run yet — treat
the first real push/pull as the integration test and report problems via the
in-app issue button.
