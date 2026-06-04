```
whois => 3000
web-check => 3001
front-end => 5173
ai-report => 3002
subdomain (recon) => 3003
service-ports (recon) => 3004
fuzzing-api (recon) => 3005
AI => 3006

docker => 6080
proxy => 5050
```

# whois (./WHOIS)


```bash
docker build -t whois .
```

```bash
docker run -d -p 3000:3000 --name wis whois
```

# Front-end (./Front-End)

```bash
docker build -t front-end .
```

```bash
docker run --name front -p 5173:5173 front-end
```

# web-check (./web-check)

```bash
docker build -t web-check .
```

```bash
docker run --name web -p 3001:3001 web-check
```
