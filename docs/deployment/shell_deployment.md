# Astro Shell: Production & Staging Deployment Guide

This document defines the deployment specification for the Astro Shell (`shell/`) gateway in production and staging environments, following 12-factor operations guidelines.

---

## 1. Automated Docker Build Pipeline

The production container is compiled using a multi-stage process to enforce isolation and minimize runtime surface area.

### Build the Image
To build the image manually or in a CI runner:
```bash
docker build -t stagea-shell:latest -f shell/Dockerfile shell/
```

### Build Arguments & Environment Checks
Our `Dockerfile` compiles the Astro SSR files using node-production constraints:
* **Build Node**: `node:22-alpine` (builder and runner).
* **Dependency Resolver**: `pnpm` under secure locked constraints (`--frozen-lockfile`).
* **Runtime User**: `node` (unprivileged GID/UID `1000:1000`).

---

## 2. Reverse Proxy Configuration (Nginx Ingress)

The Astro Shell runs as a port-bound, stateless Node.js process inside our private container network, listening on port `4321`. It must be placed behind an edge reverse proxy (such as Nginx, Traefik, or HAProxy) to handle SSL/TLS termination, request gzip compression, and secure HTTP-header forwarding.

### Standard Nginx Configuration Block
Place this block in `/etc/nginx/conf.d/stagea-shell.conf` on your edge nodes:

```nginx
# Upstream definition for load balancing (Factor VIII: Concurrency)
upstream shell_backend {
    server shell-node-1:4321 max_fails=3 fail_timeout=10s;
    server shell-node-2:4321 max_fails=3 fail_timeout=10s;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name app.stagea-stuff.com;
    
    # Force global HTTPS redirection
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name app.stagea-stuff.com;

    # SSL Certificates (Managed via Let's Encrypt / Certbot)
    ssl_certificate /etc/letsencrypt/live/app.stagea-stuff.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.stagea-stuff.com/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Gzip Compression for High Performance
    gzip on;
    gzip_proxied any;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 1000;

    # Dynamic Proxy to Astro Shell Web Nodes
    location / {
        proxy_pass http://shell_backend;
        proxy_http_version 1.1;
        
        # Keep-Alive connection optimizations
        proxy_set_header Connection "";
        
        # Request context headers (CRITICAL for 12-factor logging and OIDC verification)
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Timeouts for API gateway resilience
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

*Note on `X-Forwarded-Proto`: This header is highly critical. If the proxy fails to append `X-Forwarded-Proto: https`, the Astro server will assume the request is insecure HTTP and refuse to validate OIDC session cookies (which carry `Secure` flags in production).*

---

## 3. Production Environment Checklist

Before triggering a release, ensure these environment variables are loaded in your deployment runtime (e.g. AWS ECS Task Definition, Kubernetes deployment, or Portainer Stack):

| Variable Name | Production Expected Value | Notes |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | Enables optimal server runtime performance. |
| `HOST` | `0.0.0.0` | Binds to all network interfaces inside container. |
| `PORT` | `4321` | Custom port if overlapping on host. |
| `PUBLIC_SITE_NAME` | `Stagea Community` | Brand title displayed in headers. |
| `FORUM_URL` | `https://forum.stagea-stuff.com/` | Public URL of the NodeBB forum. |
| `WIKI_URL` | `https://wiki.stagea-stuff.com/` | Public URL of the MediaWiki instance. |
| `BLOG_URL` | `https://blog.stagea-stuff.com/` | Public URL of the Ghost blog. |
| `SHOP_URL` | `https://shop.stagea-stuff.com/` | Public URL of the Saleor storefront. |
| `AUTH_ISSUER_URL` | `https://auth.stagea-stuff.com/realms/stagea` | Keycloak realm endpoint. |
| `AUTH_CLIENT_ID` | `shell-client` | Client ID registered in Keycloak. |
| `AUTH_CLIENT_SECRET` | `sec_g57y...` (SECRET) | Keycloak client credentials secret. |
| `GHOST_CONTENT_API_KEY`| `sec_api_key` (SECRET) | Used for fetching home page summary widgets. |

---

## 4. Disposability & Graceful Shutdown (Factor IX)

To prevent active HTTP connections from being abruptly severed during a rolling deploy, the orchestrator (e.g. Docker Swarm or Kubernetes) sends a `SIGTERM` signal. The Shell process handles this as follows:

```
[ Orchestrator ] ──> Sends SIGTERM ──> [ Astro Shell Server ]
                                             │
      ┌──────────────────────────────────────┴──────────────────────────────────────┐
      ▼                                                                             ▼
[ Stop accepting new HTTP requests ]                                 [ Process active in-flight requests ]
                                                                                    │
                                                                                    ▼
                                                                     [ Cleanly close DB & Redis pools ]
                                                                                    │
                                                                                    ▼
                                                                     [ Process exits with code 0 ]
```

1. **Active Interception**: The standalone Astro Node server intercepts the system `SIGTERM` signal.
2. **Draining Mode**: Stops accepting new incoming TCP handshakes while maintaining existing connections.
3. **Connection Grace Period**: Allows active, in-flight HTTP requests up to 10 seconds to finish transmitting payloads.
4. **Shutdown**: Closes all remaining socket descriptors and database connection pools cleanly, exiting the process with code `0`.

---

## 5. Logs & Telemetry Routing (Factor XI)

The Astro Shell streams all operational logs in JSON or simple text to the container’s console streams (`stdout` / `stderr`).

### Capture & Aggregation Workflow
1. **Stdout/Stderr Generation**: The Astro Node process outputs logs:
   ```json
   {"time":"2026-07-07T12:00:00Z","level":"INFO","msg":"GET /search - query='RB25DET' - status=200 - latency=140ms"}
   ```
2. **Container Daemon Capture**: Docker captures this stream and writes it to the local driver (e.g. `json-file`).
3. **Log Collector Ingestion**: A daemon (e.g. **Promtail** or **FluentBit**) reads the stream and forwards the events.
4. **Indexing & Alerting**: Logs are indexed inside **Grafana Loki** or **Elasticsearch**, enabling instant auditing of administrative operations or system routing errors.

---

## 🔗 Related Documentation & Compliance References

* 🧭 **[Platform Master Site-Plan](../site-plan.md)** — Overall multi-site architecture, subdomain map, and current monorepo statuses.
* ⭐️ **[System 12-Factor Compliance Audit](../12_factor_compliance.md)** — Comprehensive review of Stagea monorepo compliance with all twelve principles from 12factor.net.
* 🚀 **[Development Stack Deployment Guide](./README.md)** — Entry point for deploying the entire local developer stack and managing port maps.
* 🛠 **[Per-Service Setup Guide](./services_setup.md)** — Step-by-step initial deployment and troubleshooting for each submodule.
