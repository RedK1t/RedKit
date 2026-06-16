# RedKit — Cloudflare DNS setup (domain: `redkit.uk`)

This maps the apex domain and every service subdomain to your Contabo VPS so that
Caddy (running on the server) can serve each one over HTTPS.

> **TLS model:** Caddy on the server issues **Let's Encrypt** certificates automatically.
> For that to work (and for the noVNC / scanner WebSockets to behave), **every record
> below must be set to `DNS only` (grey cloud)** — *not* proxied (orange cloud).

---

## 1. Get the server's public IP

SSH into the VPS and run:

```sh
curl -4 ifconfig.co
```

Note the IPv4 address it prints — that's `<VPS_IP>` used below.

## 2. Open the firewall for HTTP/HTTPS

Let's Encrypt validates over port 80, and traffic is served on 443:

```sh
ufw allow 80,443/tcp     # if ufw is enabled; otherwise Contabo's panel firewall
```

(Contabo VPS images usually have no firewall enabled by default — in that case nothing
to do, but make sure ports 80 and 443 are reachable.)

## 3. Add the DNS records in Cloudflare

Cloudflare dashboard → select **redkit.uk** → **DNS** → **Records** → **Add record**.

Add each of these as a **Type `A`**, **Proxy status = `DNS only` (grey cloud)**:

| Type | Name (Cloudflare) | Resolves to            | Content     | Proxy     |
|------|-------------------|------------------------|-------------|-----------|
| A    | `@`               | redkit.uk (apex)       | `<VPS_IP>`  | DNS only  |
| A    | `www`             | www.redkit.uk          | `<VPS_IP>`  | DNS only  |
| A    | `dash`            | dash.redkit.uk         | `<VPS_IP>`  | DNS only  |
| A    | `api`             | api.redkit.uk          | `<VPS_IP>`  | DNS only  |
| A    | `gateway`         | gateway.redkit.uk      | `<VPS_IP>`  | DNS only  |
| A    | `scanner`         | scanner.redkit.uk      | `<VPS_IP>`  | DNS only  |
| A    | `report`          | report.redkit.uk       | `<VPS_IP>`  | DNS only  |
| A    | `recon`           | recon.redkit.uk        | `<VPS_IP>`  | DNS only  |
| A    | `ports`           | ports.redkit.uk        | `<VPS_IP>`  | DNS only  |
| A    | `endpoints`       | endpoints.redkit.uk    | `<VPS_IP>`  | DNS only  |
| A    | `webcheck`        | webcheck.redkit.uk     | `<VPS_IP>`  | DNS only  |
| A    | `whois`           | whois.redkit.uk        | `<VPS_IP>`  | DNS only  |

### Shorter alternative (wildcard)

If you'd rather not add 12 rows, you can use just two records (both **DNS only**):

| Type | Name | Content    | Proxy    |
|------|------|------------|----------|
| A    | `@`  | `<VPS_IP>` | DNS only |
| A    | `*`  | `<VPS_IP>` | DNS only |

The `*` wildcard covers every subdomain. Caddy still requests an individual Let's Encrypt
certificate per hostname on first request, so functionally it's the same.

## 4. What each subdomain serves

| Hostname               | Service (inside Docker)        |
|------------------------|--------------------------------|
| `redkit.uk`, `www`     | Landing page                   |
| `dash.redkit.uk`       | Dashboard (Front-End app)      |
| `api.redkit.uk`        | Orchestrator control API       |
| `gateway.redkit.uk`    | Orchestrator data gateway (noVNC + interceptor) |
| `scanner.redkit.uk`    | AI vulnerability scanner (WS)  |
| `report.redkit.uk`     | AI report REST API             |
| `recon.redkit.uk`      | Recon — subdomain enumeration  |
| `ports.redkit.uk`      | Recon — open-ports scan        |
| `endpoints.redkit.uk`  | Recon — endpoint discovery     |
| `webcheck.redkit.uk`   | Web-check site analysis        |
| `whois.redkit.uk`      | WHOIS lookup                   |

## 5. Verify DNS has propagated

From your laptop (give it a few minutes after saving the records):

```sh
dig +short redkit.uk
dig +short dash.redkit.uk
dig +short gateway.redkit.uk
```

Each should print `<VPS_IP>`. Once they do, proceed with **`DEPLOY.md`** on the server —
Caddy will fetch certificates automatically the first time each hostname is hit.

---

### Notes / gotchas

- **Keep records grey-cloud.** If you orange-cloud (proxy) them, Cloudflare terminates TLS
  and Caddy's HTTP-01 challenge can fail; the noVNC/scanner WebSockets also get trickier.
  You can switch to proxied later once everything works, using a Cloudflare Origin cert and
  SSL/TLS mode = *Full (strict)* — but start with DNS only.
- While records are **DNS only**, the Cloudflare **SSL/TLS encryption mode** setting is
  irrelevant (Cloudflare isn't in the TLS path).
- DNS changes can take a few minutes to propagate; if `dig` still shows nothing, wait and
  retry rather than re-adding records.
