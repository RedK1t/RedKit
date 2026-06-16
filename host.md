# RedKit — Hosting & Deployment Guide

Goal: run RedKit with **up to 5 concurrent Kali browser containers**, plus a future
**React landing page**, for **one month**, as **cheap, easy, and reliable** as possible —
including a **cheap domain** and a **free SSL layer**.

> Prices below are approximate (early 2026) and in USD; always confirm on the provider's
> page before buying. Currency-converted from EUR where relevant.

---

## 1. What RedKit actually needs (resource sizing)

RedKit is a Docker Compose stack. Two cost drivers:

### A. The always-on base stack (6 containers)
| Service | What it is | Rough RAM idle |
|---|---|---|
| `frontend` | Vite-built React app | 50–150 MB |
| `orchestrator` | Node + dockerode (spawns Kali containers) | ~80 MB |
| `AI` (aiws) | Python scanner + RandomForest model + Cohere client | 300–600 MB |
| `Recon` | recon services (3 ports) | ~200 MB |
| `web-check` | Node site-analysis | ~150 MB |
| `whois` | small Node service | ~80 MB |
| **Base total** | | **~1.0–1.5 GB** |

### B. Each Kali browser container (the expensive part)
The per-user container (`Docker/Dockerfile`) is a **full XFCE desktop + Chromium +
TigerVNC + noVNC + dev tools**. That is not lightweight:

- **RAM:** ~0.7–1.2 GB idle, **1.5–2 GB** with Chromium actively browsing.
- **CPU:** bursty — Chromium + the desktop can each spike a core on page loads.
- **Disk (image):** the built `kalinew:latest` image is large (Kali rolling + XFCE +
  Chromium + Sublime + a pyenv Python) — budget **~5–8 GB** for the image alone.

> ⚠️ **Important:** `Back-End/docker.js` currently creates each container with **no memory
> limit** (`HostConfig` only sets a restart policy). On a small host, 5 unbounded Chromium
> desktops can OOM the box. **Before going to production, cap each container** — see §7.

### C. Host sizing for "max 5 Kali containers"
| Scenario | RAM math | Recommended host RAM | vCPU |
|---|---|---|---|
| 5 containers, capped at ~1.2 GB each + base + OS | 6 + 1.5 + 1 ≈ **8.5 GB** | **8 GB (tight)** | 4 |
| 5 containers, realistic active browsing + base + OS | 8–10 + 1.5 + 1 ≈ **12 GB** | **16 GB (comfortable)** ✅ | 6–8 |

- **Disk:** **40–60 GB SSD/NVMe** (Kali image + base images + Docker layers + logs).
- **Bandwidth:** browsing traffic — a few hundred GB/mo. Most EU VPS include 20 TB, so a
  non-issue. (US clouds with metered egress can surprise you — see Oracle note.)

**Bottom line: 16 GB / 6–8 vCPU / 60 GB NVMe is the comfortable target; 8 GB / 4 vCPU is
the floor if you enforce per-container memory caps and don't expect all 5 hammering at once.**

---

## 2. Host options compared (cheapest → most reliable)

| Provider / plan | vCPU | RAM | Disk | ~ / month | Notes |
|---|---|---|---|---|---|
| **Oracle Cloud — Always Free (Ampere ARM A1)** | 4 | **24 GB** | 200 GB | **$0** | Free forever, but **ARM64** (need arm64 images), capacity is often "out of stock," card required, idle instances can be reclaimed. Cheapest possible if you can get it. |
| **Contabo — Cloud VPS 30 NVMe** | 8 | **24 GB** | ~100 GB NVMe | **~$13–14** | Huge RAM for the price, x86. Oversubscribed/variable performance + slower network; fine for a 1-month trial. |
| **Hetzner — CPX31** | 4 | 8 GB | 160 GB NVMe | **~$14** | Excellent price/perf, x86, 20 TB traffic. Works for 5 containers **only with memory caps**. |
| **Hetzner — CPX41** ✅ recommended | 8 | **16 GB** | 240 GB NVMe | **~$27** | Best balance: comfortably runs 5 Kali + full stack, reliable, easy. |
| DigitalOcean / Vultr / Linode (8 GB std) | 4 | 8 GB | 160 GB | ~$48 | Polished UX but ~2× the price for the same specs. |

### Recommendation
- **Best overall (recommended): Hetzner CPX41 — 16 GB, 8 vCPU, ~$27/mo.** Reliable, x86 (your
  images build as-is), runs all 5 containers without babysitting. Pay-per-hour, so a single
  month is ~$27 and you can destroy it after.
- **Cheapest reliable paid: Contabo VPS 30 — 24 GB, ~$13–14/mo** if you want max RAM headroom
  on a budget and can tolerate variable performance. (Watch for a one-time setup fee on some
  plans — pick the no-setup-fee option.)
- **Absolute cheapest ($0): Oracle Cloud Always Free 24 GB ARM** — only if you accept ARM64
  images and the signup/capacity hassle. Great for a free month if you get it.
- **Tightest budget on Hetzner: CPX31 — 8 GB, ~$14/mo** + enforce the §7 memory caps.

> All of these are billed hourly/monthly with no lock-in, so "one month" = spin up, use,
> destroy. Set a calendar reminder to delete the server so it doesn't keep billing.

---

## 3. The React landing page → host it FREE (separately)

Don't put the static landing page on the paid VPS — serve it from a free static/CDN host:

- **Cloudflare Pages** (recommended), **Vercel**, or **Netlify** — all have a free tier that
  easily covers a marketing landing page, with **automatic HTTPS** included.
- Connect your Git repo → every push auto-builds and deploys. Zero server cost.
- Point a subdomain at it, e.g. `www.yourdomain.xyz` / apex → landing page; `app.yourdomain.xyz`
  → the VPS app.

This keeps the heavy VPS dedicated to the Docker stack and the landing page at **$0**.

---

## 4. Domain (cheap)

Buy from a registrar that sells at cost (avoid the upsells):
- **Cloudflare Registrar** — wholesale price, no markup (needs the domain's DNS on Cloudflare).
- **Porkbun** or **Namecheap** — frequent cheap promos.

TLD pick for a cheap one-month/first-year:
- **`.xyz` / `.site` / `.online`** — often **$1–3 first year**.
- **`.com`** — ~$10–12/yr if you want the "real" look.

> Domains bill **per year minimum** (you can't rent for one month), so the cheapest realistic
> domain spend is **~$1–3** for a first-year `.xyz`. If you truly want $0, use a free
> wildcard-DNS hostname like `app.<ip>.sslip.io` (resolves any IP, works with Let's Encrypt) —
> ugly but free and instant.

---

## 5. SSL layer → FREE

Two easy, free paths (pick one):

1. **Caddy reverse proxy (recommended, simplest).** Run Caddy in front of the stack; it gets
   and auto-renews **Let's Encrypt** certs with zero config beyond your domain name. One small
   `Caddyfile` reverse-proxies the frontend and the orchestrator gateway. SSL = free + automatic.
2. **Cloudflare proxy.** Put the domain behind Cloudflare (orange-cloud); you get **free
   Universal SSL** at the edge instantly. Combine with Cloudflare Tunnel to avoid exposing the
   VPS IP/ports at all.

Either way the SSL cost is **$0**.

---

## 6. Estimated total cost — one month

| Item | Recommended | Cheapest |
|---|---|---|
| Server | Hetzner CPX41 16 GB — **~$27** | Oracle Free 24 GB ARM — **$0** |
| Domain | `.xyz` first year — **~$2** | `sslip.io` hostname — **$0** |
| SSL | Caddy / Let's Encrypt — **$0** | Caddy / Let's Encrypt — **$0** |
| Landing page | Cloudflare Pages — **$0** | Cloudflare Pages — **$0** |
| **Total (1 month)** | **≈ $29** | **≈ $0–2** |

---

## 7. Easiest deployment (single VPS) — step by step

1. **Create the server** (Hetzner/Contabo/Oracle), Ubuntu 22.04/24.04 LTS, add your SSH key.
   - On Oracle (ARM) pick an **arm64** Ubuntu image; everything below is identical, your
     Docker images just build for arm64.
2. **Install Docker + Compose:**
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```
3. **Point DNS:** create an `A` record `app.yourdomain.xyz → <server IP>` at your registrar/Cloudflare.
4. **Clone & configure env:** copy the repo up, fill each service's `.env`
   (`Back-End/.env`, `AI/.env`, `Front-End/.env`, …).
   - ⚠️ **The frontend bakes `VITE_*` URLs at build time**, so set the public URLs
     (`VITE_SUPABASE_URL`, the orchestrator gateway URL on 3009, the AI WS on 3006/3007, the
     report REST on 3007) to your **domain over HTTPS** *before* building, not `localhost`.
5. **Cap the Kali containers** (prevents OOM) — in `Back-End/docker.js`, add to the
   `HostConfig` of the per-user create:
   ```js
   HostConfig: {
     RestartPolicy: { Name: "no" },
     Memory: 1288490189,        // ~1.2 GB hard cap per container
     MemorySwap: 1288490189,    // = Memory → disable swap blow-up
     NanoCpus: 1500000000,      // ~1.5 CPU per container
     ShmSize: 536870912,        // 512 MB /dev/shm so Chromium doesn't crash
   },
   ```
   (Also consider an idle-reaper that stops containers after N minutes unused, so 5 caps are
   rarely all live at once.)
6. **Build & run:**
   ```bash
   docker compose build           # builds base services
   docker compose build Kali      # builds the per-user kalinew:latest image (manual profile)
   docker compose up -d
   ```
7. **Add SSL + routing with Caddy** (one extra container or host package). Minimal `Caddyfile`:
   ```
   app.yourdomain.xyz {
       reverse_proxy /gateway/* localhost:3009
       reverse_proxy localhost:5173
   }
   ```
   Caddy fetches the Let's Encrypt cert automatically on first request. Done — HTTPS live.
8. **Landing page:** push the React landing repo to GitHub → connect to **Cloudflare Pages** →
   map the apex/`www` domain there. (Independent of the VPS.)
9. **Tear down after the month:** `docker compose down` and **delete the server** in the
   provider console so billing stops.

---

## 8. TL;DR
- **Need:** ~16 GB RAM / 6–8 vCPU / 60 GB NVMe for a comfortable 5-container run (8 GB/4 vCPU
  floor *with* memory caps).
- **Recommended host:** **Hetzner CPX41 (16 GB) ≈ $27/mo** — reliable, x86, no surprises.
- **Cheapest:** **Oracle Cloud Always Free 24 GB ARM = $0** (if you accept ARM + signup hassle),
  else **Contabo 24 GB ≈ $13/mo**.
- **Domain:** `.xyz` first year ≈ **$1–3** (Porkbun/Cloudflare), or `sslip.io` = $0.
- **SSL:** **free** via Caddy + Let's Encrypt (or Cloudflare).
- **Landing page:** **free** on Cloudflare Pages / Vercel / Netlify.
- **All-in for one month: ≈ $29 recommended, ≈ $0–2 absolute cheapest.**
- **Before deploying:** add per-container memory/CPU caps in `Back-End/docker.js` (currently
  unbounded) and set the frontend's `VITE_*` URLs to your HTTPS domain before building.

---

## 9. Per-service subdomains on one Hetzner box (reverse proxy)

**Can you run this on a Hetzner CPX41 and give each service its own subdomain? Yes.**
**Do you need a reverse proxy? Yes.**

### Why a reverse proxy is required
The CPX41 has **one public IP**. DNS subdomains only map a *name → that IP* — DNS has no
concept of a port. So `app.`, `scanner.`, `gateway.`, … all resolve to the same IP, and
something on the box must read the incoming hostname and forward it to the correct internal
container port. That "something" is the reverse proxy. Without it your only option is ugly
`name.yourdomain.xyz:5173`-style URLs with per-port SSL you manage yourself.

Use **Caddy** — it auto-fetches + renews Let's Encrypt certs for every subdomain and proxies
WebSockets transparently (needed for the scanner WS and the gateway).

### ⚠️ CPX41 (x86) vs CAX41 (ARM)
Hetzner's config page has a **VCPU toggle**: **Intel/AMD = CPX41 (x86_64)** vs
**Ampere = CAX41 (ARM64)**. They're priced ~the same (CPX41 ≈ €27, CAX41 ≈ €32). 
- **Pick CPX41 (Intel/AMD)** for zero hassle — your Docker images build as-is.
- If you pick **CAX41 (Ampere/ARM)**, every image (Kali rolling, Chromium, Node, Python)
  must build for **arm64**. Kali and Chromium do have arm64 builds, but expect extra
  troubleshooting. Only choose ARM if you specifically want it.
- **Region:** the dropdown offers **NBG-1 (Nuremberg, DE)** and **HEL-1 (Helsinki, FI)** for
  these plans — pick whichever is closer to most of your users (see §10 to measure).

> **Already wired into this repo.** A ready **`Caddyfile`** (full per-service map) lives at the
> repo root, and `docker-compose.yaml` already contains a **commented `caddy` service** + a
> **`landing` service** (the static landing page). At deploy time you only uncomment Caddy, set
> `DOMAIN`, and point DNS — the steps below.

### Step 1 — DNS (Cloudflare/registrar): one wildcard covers everything
```
*.yourdomain.xyz   A   <server IP>
yourdomain.xyz     A   <server IP>
```

### Step 2 — enable Caddy in `docker-compose.yaml`
Uncomment the `caddy` service **and** the `volumes:` block at the bottom, then set `DOMAIN`:
```yaml
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    environment:
      - DOMAIN=yourdomain.xyz
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - default        # reach landing/frontend/aiws/rec/web/whoisc by name
      - redkit-net     # reach the orchestrator (lives only on redkit-net)

volumes:
  caddy_data:
  caddy_config:
```
Caddy joins **both** networks because the `orchestrator` is isolated on `redkit-net` while the
other services use the default compose network. It reaches everything by **container name**, so
the proxied services don't need to publish host ports (only Caddy needs 80/443).

### Step 3 — the `Caddyfile` (already in the repo; one `{$DOMAIN}` drives all subdomains)
```
{$DOMAIN}, www.{$DOMAIN}  { reverse_proxy landing:80 }       # landing page (apex)
dash.{$DOMAIN}            { reverse_proxy frontend:5173 }    # the dashboard app
gateway.{$DOMAIN}         { reverse_proxy orchestrator:3009 }
api.{$DOMAIN}             { reverse_proxy orchestrator:3008 }
scanner.{$DOMAIN}         { reverse_proxy aiws:3006 }
report.{$DOMAIN}          { reverse_proxy aiws:3007 }
recon.{$DOMAIN}           { reverse_proxy rec:3003 }
webcheck.{$DOMAIN}        { reverse_proxy web:3001 }
whois.{$DOMAIN}           { reverse_proxy whoisc:3000 }
```
Caddy grabs SSL on first request; all subdomains go live over HTTPS; WebSockets just work.

### RedKit-specific notes
- **Landing page = apex; dashboard = `dash.`** The marketing landing page (`Landing/`, served by
  the `landing` container) is at `{domain}.{tld}`; the actual app (`Front-End`) is at
  `dash.{domain}.{tld}`. Set **`Landing/.env` `VITE_DASH_URL=https://dash.{domain}.{tld}`**
  before building so the "Launch Dashboard" button points to the app.
- **No subdomain per Kali container.** The per-user containers stay on `redkit-net` and are
  reached **through** `gateway.{domain}` (orchestrator port 3009) by internal IP — that single
  gateway subdomain serves all 5.
- **Set the frontend `VITE_*` URLs to these HTTPS subdomains *before* `docker compose build
  frontend`** (`dash.`/`gateway.`/`scanner.`/`report.`/`recon.` …). They're baked at build time,
  so rebuild `frontend` after changing `Front-End/.env`.
- **Alternative — Cloudflare Tunnel** instead of Caddy: same subdomain→port mapping, SSL at
  Cloudflare's edge, and **nothing exposed on the VPS** (no open 80/443, IP hidden). Slightly
  more setup, more locked-down.

---

## 10. Testing server latency

### A. Before you buy — test the datacenter from where your users are
Hetzner publishes public **speed-test / looking-glass** endpoints per location. From your own
machine (or your users' region):

- **Ping the datacenter's test IP** (lowest round-trip = closest):
  ```bash
  # Nuremberg (NBG) and Helsinki (HEL) looking-glass hosts:
  ping -c 5 nbg.icmp.hetzner.com
  ping -c 5 hel.icmp.hetzner.com
  ```
  (Hetzner also hosts downloadable test files at `https://<loc>.hetzner.com/...` and a
  looking-glass page — search "Hetzner looking glass" for the current URLs.)
- Rule of thumb: **<30 ms feels instant, 30–80 ms is fine, >150 ms is sluggish** for an
  interactive remote desktop (your noVNC browser sessions are latency-sensitive).
- Pick **NBG-1 vs HEL-1** by whichever pings lower for your audience.

### B. After it's running — measure the live server
SSH in / from your laptop:

- **Round-trip latency (ICMP):**
  ```bash
  ping -c 20 app.yourdomain.xyz        # avg/min/max/mdev at the bottom
  ```
- **Per-hop path + packet loss (best single tool):**
  ```bash
  mtr -rwzbc 50 app.yourdomain.xyz     # report mode, 50 packets, shows where latency is added
  ```
- **Real HTTPS request timing (DNS → TCP → TLS → first byte):**
  ```bash
  curl -w "dns:%{time_namelookup}s tcp:%{time_connect}s tls:%{time_appconnect}s ttfb:%{time_starttransfer}s total:%{time_total}s\n" \
       -o /dev/null -s https://app.yourdomain.xyz
  ```
  `ttfb` (time-to-first-byte) is the number that matters for app responsiveness.
- **WebSocket latency** (scanner/gateway): open the app, watch the browser **DevTools →
  Network → WS** frame timings, or use `websocat`:
  ```bash
  websocat wss://scanner.yourdomain.xyz   # then watch round-trip on sent/received frames
  ```
- **noVNC interactive feel:** the honest test is just opening a Kali session and dragging a
  window — if it lags, you're either too far from the region (§A) or CPU-starved (check
  `htop` / `docker stats` while interacting).
- **Server-side resource pressure** (latency is often CPU/RAM, not network):
  ```bash
  docker stats          # live per-container CPU/MEM
  htop                  # overall load; watch load average vs 8 vCPU
  ```

### C. Quick interpretation
- High `ping` but low `docker stats` load → **network/region** problem → pick the closer
  Hetzner location or put **Cloudflare** in front (edge caching/closer TLS termination).
- Low `ping` but laggy desktop + high `docker stats` → **CPU/RAM** pressure → enforce the §7
  per-container caps or reduce concurrent containers.
