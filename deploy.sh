#!/usr/bin/env bash
# RedKit VPS deploy dispatcher — invoked by each repo's GitHub Actions workflow
# over SSH as: /opt/redkit/deploy.sh <RepoName>
#
# It pulls the repo that changed and rebuilds only that service. .env files live
# on the server (gitignored) and are never touched by git pull.
set -euo pipefail

cd /opt/redkit
C="docker compose -f docker-compose.prod.yaml"

case "${1:-orchestration}" in
  # Umbrella repo (compose / Caddyfile / this script changed): pull root, reconcile.
  orchestration) git pull --ff-only; $C up -d ;;

  # Full update: pull every repo, build ALL images (including Kali), then start
  # everything EXCEPT Kali (Kali stays on the manual profile — it's launched
  # per-user by the orchestrator, never run as a standing service).
  all)
    git pull --ff-only
    for r in Front-End Landing AI Back-End Recon web-check WHOIS Docker; do
      echo "== pulling $r =="
      git -C "$r" pull --ff-only
    done
    $C --profile manual build     # build all services + the Kali image
    $C up -d                      # start all default services (Kali excluded)
    ;;

  Front-End) git -C Front-End pull --ff-only; $C up -d --build frontend ;;
  Landing)   git -C Landing   pull --ff-only; $C up -d --build landing ;;
  AI)        git -C AI        pull --ff-only; $C up -d --build AI ;;
  Back-End)  git -C Back-End  pull --ff-only; $C up -d --build orchestrator ;;
  Recon)     git -C Recon     pull --ff-only; $C up -d --build Recon ;;
  web-check) git -C web-check pull --ff-only; $C up -d --build web-check ;;
  WHOIS)     git -C WHOIS     pull --ff-only; $C up -d --build whois ;;

  # Kali is built per-user on demand; rebuild the image so new sessions use it.
  Docker)    git -C Docker    pull --ff-only; $C build Kali ;;

  *) echo "deploy.sh: unknown service '$1'" >&2; exit 1 ;;
esac

echo "deploy.sh: '${1:-orchestration}' deployed."
