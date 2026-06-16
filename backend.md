
Prerequisites (once)

cd /home/hanafi/Documents/RedKit
docker compose build Kali        # builds kalinew:latest (the per-user image)
The orchestrator spawns copies of this image, so it must exist locally first.

Option A — Test the backend alone (fast, no front-end)

This proves containers actually get created/stopped. You need a real Supabase token.

1. Get a token: Open the RedKit front-end, log in, then in the browser devtools console:
JSON.parse(localStorage.getItem("sb-zxcmlsafspvebelqymhe-auth-token")).access_token
Copy that string.

2. Run the orchestrator (already has deps installed):
cd /home/hanafi/Documents/RedKit/Back-End
node server.js

3. In another terminal, exercise it:
TOKEN="<paste access_token>"

# Create/start your container -> returns vncUrl + proxyWsUrl
curl -s -X POST http://localhost:3008/session/open \
  -H "Authorization: Bearer $TOKEN" | jq

# Confirm the container exists with two published ports
docker ps --filter label=redkit.managed=true

# Keep alive
curl -s -X POST http://localhost:3008/session/heartbeat -H "Authorization: Bearer $TOKEN"

# Open the vncUrl from the open response in a browser -> you should see the Kali desktop

4. Verify the 5-min idle stop: stop sending heartbeats and wait 5 minutes → docker ps shows the container stopped (still present). To test faster, restart the orchestrator with a short timeout:
IDLE_TIMEOUT_MS=20000 node server.js   # 20s idle

5. Verify reuse: call /session/open again → same container name restarts, new ports returned.

Option B — Full end-to-end through the UI

cd /home/hanafi/Documents/RedKit
docker compose up -d --build orchestrator frontend
Then in the app: log in → Proxy → Interceptor → Open Browser. It should open the noVNC tab, and the interceptor’s traffic now comes from your container. Turn the interceptor on and browse a site inside the VNC
window — requests appear in the table.

▎ Note: Vite bakes VITE_* at build time, so the new VITE_orchestrator_REST_url only takes effect after the --build. For live UI iteration, run npm run dev in Front-End/ (picks up .env directly) while the
▎ orchestrator runs separately.

Cleanup

docker ps -a --filter label=redkit.managed=true
docker rm -f $(docker ps -aq --filter label=redkit.managed=true)

Two things to watch for locally

- Docker socket permissions: running node server.js directly works if your user is in the docker group (docker ps works without sudo). In compose it’s handled by the mounted socket.
- noVNC connecting: the vncUrl is http://localhost:<port>/vnc.html. If it loads but won’t connect, that’s the container still booting VNC — give it a few seconds and reconnect.
