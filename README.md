<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-light.svg">
    <img src="docs/assets/logo-dark.svg" alt="RedKit" width="140">
  </picture>
</p>

<h1 align="center">RedKit</h1>

<p align="center">
  A modular, web-based penetration-testing framework.<br>
  Recon, web analysis, traffic interception, AI-assisted vulnerability scanning and reporting, all in one dashboard.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-red" alt="MIT">
  <img src="https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white" alt="Docker Compose">
  <img src="https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black" alt="React">
  <img src="https://img.shields.io/badge/Python-FastAPI-009688?logo=fastapi&logoColor=white" alt="FastAPI">
</p>

---

> Graduation project. Built for authorized security testing, research and education only.

## Overview

Each RedKit capability is an independent containerized microservice with its own repository. A React dashboard ties them together, and every user gets their own Kali Linux desktop in the browser (noVNC) for hands-on tooling.

This repository is the **umbrella**: it holds the Docker Compose stack, the production deploy setup (Caddy + GitHub Actions) and the architecture docs.

## Repositories

| Repo | What it does | Stack | Port |
|---|---|---|---|
| [Front-End](https://github.com/RedK1t/Front-End) | Web dashboard | React 19, TypeScript, Vite, Tailwind | `5173` |
| [WHOIS](https://github.com/RedK1t/WHOIS) | Domain WHOIS and DNS lookup | Node.js, Express | `3000` |
| [web-check](https://github.com/RedK1t/web-check) | Passive web analysis (TLS, headers, tech stack…) | Node.js, Express, Puppeteer | `3001` |
| [AI-Report](https://github.com/RedK1t/AI-Report) | Report generation, CVSS, PDF export | Python, FastAPI | `3002` |
| [Recon](https://github.com/RedK1t/Recon) | Subdomains, open ports, endpoint fuzzing | Python, FastAPI | `3003–3005` |
| [AI](https://github.com/RedK1t/AI) | SQLi / XSS scanner with LLM + ML analysis | Python | `3006–3007` |
| [Back-End](https://github.com/RedK1t/Back-End) | Per-user Kali container orchestrator + gateway | Node.js, dockerode | `3008–3009` |
| [Proxy](https://github.com/RedK1t/Proxy) | Interceptor, Repeater, Intruder | Python, mitmproxy, FastAPI | `5050` |
| [Docker](https://github.com/RedK1t/Docker) | Kali XFCE desktop over noVNC | Kali Linux | `6080` |
| [Landing](https://github.com/RedK1t/Landing) | Marketing landing page | React, Vite | — |

## Quick start

Requires Docker with Compose v2.

```bash
git clone https://github.com/RedK1t/RedKit.git && cd RedKit
for r in Front-End WHOIS web-check AI-Report Recon AI Back-End Proxy Docker Landing; do
  git clone https://github.com/RedK1t/$r.git
done

# each service ships a template.env (or .env.example), so copy and fill in your own keys
for f in */template.env; do cp "$f" "$(dirname "$f")/.env"; done

docker compose up --build
```

Then open the dashboard at <http://localhost:5173>.

API keys you'll need: **Cohere** and/or **Gemini** (AI scanner), **Supabase** (auth/storage) and **Groq** (assistant). No secrets are committed to any repo.

## Production

[`docker-compose.prod.yaml`](docker-compose.prod.yaml) + [`Caddyfile`](Caddyfile) serve each service on its own subdomain with automatic HTTPS, and a push to any repo's `main` redeploys just that service. See [DEPLOY.md](DEPLOY.md) and [DNS-SETUP.md](DNS-SETUP.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md): system design, data flow and the zero-knowledge encryption model
- [E2EE sharing proof of concept](docs/POC-E2EE-Sharing.md)
- [Diagram](docs/Diagram.drawio.pdf)
- Each service repo has its own README and API docs.

## License

[MIT](LICENSE).

**Disclaimer:** only scan systems you own or have explicit written permission to test. The authors accept no liability for misuse.
