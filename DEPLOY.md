# RedKit — VPS deployment & auto-deploy runbook

Production runs from **`/opt/redkit`** on the VPS (domain **redkit.uk**). The umbrella repo
`RedK1t/RedKit` is the deploy root; the 8 subprojects are cloned into it. Every `git push` to a
repo's `main` triggers a GitHub Action that SSHes in and rebuilds only that service via `deploy.sh`.

Do the DNS step first — see **`DNS-SETUP.md`**.

---

## Architecture

```
/opt/redkit/                         (clone of RedK1t/RedKit)
├── docker-compose.prod.yaml         Caddy-enabled, only 80/443 published
├── Caddyfile                        per-subdomain routing
├── deploy.sh                        CI calls this over SSH
├── .env                             DOMAIN=redkit.uk           (server-side)
├── Front-End/  …/.env               (clone + server-side secrets)
├── Landing/    …/.env
├── AI/         …/.env
├── Back-End/   …/.env
├── Recon/      …/.env
├── web-check/  …/.env
├── WHOIS/      …/.env
└── Docker/                          (Kali image build context)
```

`.env` files are **gitignored** and live only on the server — `git pull` never overwrites them.

---

## One-time bootstrap

### 1. (Recommended) dedicated deploy user
```sh
adduser deploy && usermod -aG docker deploy
sudo mkdir -p /opt/redkit && sudo chown -R deploy:deploy /opt/redkit
su - deploy
```
(Or just use `root` and skip this.)

### 2. Authorize the CI SSH key
On your laptop the keypair `redkit_deploy` / `redkit_deploy.pub` was generated. Put the **public**
key on the server so GitHub Actions can SSH in:
```sh
# as the deploy user (or root) on the VPS:
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "<contents of redkit_deploy.pub>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```
Make sure inbound **TCP 22** is reachable by GitHub's runners, and **80/443** are open.

### 3. Authenticate git for the private repos
```sh
gh auth login          # HTTPS; lets git clone/pull the private RedK1t repos
# (alternative: add per-repo read-only deploy keys instead of gh auth)
```

### 4. Clone the umbrella + all subprojects
```sh
git clone https://github.com/RedK1t/RedKit.git /opt/redkit
cd /opt/redkit
for r in Front-End Landing AI Back-End Recon web-check WHOIS Docker; do
  git clone "https://github.com/RedK1t/$r.git" "$r"
done
```

### 5. Install the server-side secrets (once)
From your laptop, copy the prepared production `.env` files up (they have the public-subdomain
`VITE_*` URLs, `PUBLIC_BASE_URL`, and a fresh `GATEWAY_SECRET`):
```sh
for s in Front-End Landing AI Back-End Recon web-check WHOIS; do
  scp RedKit-Deploy/$s/.env  deploy@<VPS_IP>:/opt/redkit/$s/.env
done
scp RedKit-Deploy/.env       deploy@<VPS_IP>:/opt/redkit/.env     # DOMAIN=redkit.uk
```

### 6. First build & start
```sh
cd /opt/redkit
docker compose -f docker-compose.prod.yaml build Kali        # per-user browser image (slow, multi-GB)
docker compose -f docker-compose.prod.yaml up -d --build      # everything else + Caddy
docker compose -f docker-compose.prod.yaml logs -f caddy      # watch Let's Encrypt certs issue
```
Verify: `curl -I https://redkit.uk` and `curl -I https://dash.redkit.uk`.

---

## Continuous deploy (after bootstrap)

Each repo has `.github/workflows/deploy.yml`. On push to `main` it runs:
`/opt/redkit/deploy.sh <RepoName>` over SSH, which pulls that repo and rebuilds its service.

| Push to repo | Rebuilds |
|---|---|
| `RedKit` (umbrella) | `deploy.sh orchestration` → `up -d` (compose/Caddy reload) |
| `Front-End` | `frontend` (Vite rebuild) |
| `Landing` | `landing` (Vite rebuild) |
| `AI` | `AI` |
| `Back-End` | `orchestrator` |
| `Recon` | `Recon` |
| `web-check` | `web-check` |
| `WHOIS` | `whois` |
| `Docker` | `Kali` image rebuilt for next session |

Required GitHub secrets on **every** repo: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY` (private key).

---

## Manual ops cheatsheet
```sh
cd /opt/redkit
P="docker compose -f docker-compose.prod.yaml"
$P ps                       # status
$P logs -f <service>        # frontend, aiws, orchestrator, caddy, rec, web, whoisc, landing
$P up -d --build <service>  # manual redeploy of one service
./deploy.sh Front-End       # what CI runs (pull + rebuild one service)
./deploy.sh all             # pull ALL repos, build everything incl. Kali, start all except Kali
```

### Notes
- Changed a `VITE_*` value in `Front-End/.env` / `Landing/.env`? They bake at build time →
  `./deploy.sh Front-End` (rebuild). A bare `up -d` won't pick it up.
- Caddy certs/state persist in the `caddy_data` / `caddy_config` named volumes — don't delete them.
- `redkit-net` is the orchestrator ↔ per-user-container network; keep it in sync with
  `DOCKER_NETWORK` in `Back-End/.env`.
