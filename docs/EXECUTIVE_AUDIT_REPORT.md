# Stagea Platform: Executive Architecture Audit & Quality Report

This document compiles the findings of our platform-wide **12-Factor Compliance Audit** and the **Astro Shell Code Readiness Check**. It highlights operational gaps, assigns quality grades, and outlines a prioritized remediation roadmap to transition our services from dev/staging prototypes into an elite, production-grade ecosystem.

---

```mermaid
radar
    title Stagea Platform Quality Matrix
    "I. Codebase" : 5
    "II. Dependencies" : 5
    "III. Config" : 5
    "IV. Backing Services" : 5
    "V. Build, Release, Run" : 4
    "VI. Processes" : 5
    "VII. Port Binding" : 5
    "VIII. Concurrency" : 5
    "IX. Disposability" : 3.8
    "X. Dev/Prod Parity" : 5
    "XI. Logs" : 5
    "XII. Admin Processes" : 2.5
```

---

## 1. Executive Summary & Readiness Posture

* **Overall Platform 12-Factor Score**: **91% Compliance** (10/12 Factors fully satisfied, 1 Partial, 1 Planned).
* **Astro Shell Code Quality Grade**: **A- (Staging-Ready)**.
* **Core Operational Strength**: High decoupling, absolute environmental parameter configuration, and robust containerization across all active modules.
* **Primary System Gaps**: Lack of standard container termination signaling (disposability), missing live OIDC Keycloak servers (relying on mock session simulation for local speed), and lack of version-controlled, one-off database migration tasks.

---

## 2. 12-Factor Compliance Gap Analysis

We have analyzed our platform architecture against the [12-Factor App methodology](https://12factor.net/). While our design is highly compliant, we must remediate the following gaps to ensure bulletproof operations under high production concurrency:

### Gap 1: Factor IX (Disposability) — Node.js Termination Signaling
* **Impact**: **MEDIUM**
* **Finding**: The Astro Shell runs natively under Node.js inside Alpine containers. On rolling deploys or container restarts, the orchestrator (Docker/Kubernetes) issues a `SIGTERM` signal. Currently, Node.js does not catch this, resulting in the container process exiting abruptly, severing active browser connections, and dropping active requests.
* **Remediation**: Write a process signal catcher in the container entrypoint or a custom server launcher wrapper in `shell/src/server.mjs` to intercept `SIGTERM`, stop accepting new requests, drain active sockets within a 10s grace period, and exit cleanly with code `0`.

### Gap 2: Factor V (Build, Release, Run) — Manifest Orchestration
* **Impact**: **LOW**
* **Finding**: We cleanly separate building code (via multi-stage `Dockerfiles`) and running processes. However, we do not maintain versioned release manifests combining the immutable build tags with their target environment configuration variables, meaning rolling back a staging release requires manual environment parameter tracing.
* **Remediation**: Build a unified Release config directory or deploy a GitOps tool (such as ArgoCD or port-managed docker stacks) that records exact release IDs combining `image: SHA` + `config: hash` to enable instantaneous, error-free rollbacks.

### Gap 3: Factor XII (Admin Processes) — One-Off Task Automation
* **Impact**: **HIGH**
* **Finding**: Administrative tasks like seeding initial forum categories, running wiki database migrations, or backing up directus catalogs are currently documented as manual developer terminal commands rather than structured, version-controlled scripts.
* **Remediation**: Create a `services/admin/` task runner directory in our monorepo housing official migration and seed scripts, executed exclusively in transient, short-lived container instances (`docker compose run --rm`) rather than inline on persistent servers.

---

## 3. Shell Site Readiness Audit

This audit evaluates the codebase of our user-facing **Astro Shell (`shell/`)** on a per-module basis to score type-safety, resilience, and architectural conformance:

| Code Module | Rating | Current Status | Key Technical Finding | Required Remediation |
| :--- | :---: | :--- | :--- | :--- |
| **`astro.config.mjs`** | 🟢 **A** | Production-Ready | Dynamic environment schemas are strictly typed and fully validated. | Add trailing-slash validators to URL strings. |
| **`Dockerfile` & compose** | 🟢 **A-** | Production-Ready | Clean separation of build/run stages. Runs under non-privileged user `node`. | Set container CPU/Memory bounds inside compose configs. |
| **`src/lib/auth.ts`** | 🟡 **B+** | Staging-Ready | Clean OIDC claim parsing and group permissions inheritance mapping. | Swap expensive userinfo checks for local JWT JWKS signature validation. |
| **`src/lib/search.ts`** | 🟡 **B+** | Staging-Ready | Concurrent parallel fetches with robust network timeouts. | Extract all content API keys to `astro.config.mjs` env schemas. |
| **`src/pages/search.astro`** | 🟡 **B+** | Staging-Ready | Beautiful, fully server-rendered federated UI with source badges. | Add progressive client-side AJAX fetches to prevent page reloads. |
| **`src/pages/account.astro`** | 🟡 **B** | Staging-Ready | High utility simulated account switchboard for rapid local testing. | Auto-bypass switchboard if real `AUTH_ISSUER_URL` is active. |
| **`src/pages/admin.astro`** | 🟡 **B+** | Staging-Ready | Real-time backend service ping status and latency monitor. | Log administrative actions to container standard streams. |

---

## 4. Prioritized Improvement Roadmap

We organize our technical remediation into high-impact vertical slices, following our **6-Step Feature Loop**:

```
                       [ Remediation Queue ]
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  High Priority   │    │ Medium Priority  │    │  Low Priority    │
│  - Auth & JWKS   │    │  - AJax Search   │    │  - Port Sizing   │
│  - Task Scripts  │    │  - Graceful Exit │    │  - Pre-fetching  │
└──────────────────┘    └──────────────────┘    └──────────────────┘
```

### 🔴 High Priority (Sprint 1 Focus - Core Operations)
1. **OIDC Signature Validation (`src/lib/auth.ts`)**: Integrate a JSON Web Key Set (JWKS) validation algorithm to verify Keycloak token signatures locally inside the Astro server process, removing runtime network dependencies.
2. **Version-Controlled Administration Scripts (`services/admin/`)**: Codify database migration and setup tasks for MediaWiki and NodeBB inside versioned scripts to satisfy Factor XII.

### 🟡 Medium Priority (Sprint 2 Focus - UX & Robustness)
1. **Node.js Process Disposability Wrapper (`Dockerfile`)**: Implement `SIGTERM` handlers in the Shell entrypoint process to allow clean connection draining.
2. **AJAX Progressive Search (`src/pages/search.astro`)**: Enhance the search page UI with dynamic client-side JS fetches to load results asynchronously, increasing page responsiveness.

### 🔵 Low Priority (Sprint 3 Focus - Quality of Life)
1. **Astro Link Prefetching (`src/pages/index.astro`)**: Add standard prefetch tags to our headers to accelerate client transition speeds.
2. **Container Sizing Bounds (`docker-compose.yml`)**: Restrict container resource profiles (CPU/Memory limits) to insulate hosts from rogue threads.

---

## 🔗 Related Documentation & Design References

* 🧭 **[Platform Master Site-Plan](./site-plan.md)** — Overall multi-site architecture, subdomain map, and current monorepo statuses.
* ⭐️ **[System 12-Factor Compliance Audit](./12_factor_compliance.md)** — Comprehensive review of Stagea monorepo compliance with all twelve principles from 12factor.net.
* 🚀 **[Development Stack Deployment Guide](./deployment/README.md)** — Entry point for deploying the entire local developer stack and managing port maps.
* 🐳 **[Shell 12-Factor Implementation Plan](./shell/12_FACTOR_PLAN.md)** — Shell-specific 12-factor operations audit and improvement goals.
* 🚦 **[Shell Quality Readiness Ratings](./shell/READINESS_RATING.md)** — Per-file quality assessments, typescript audits, and production path for the Astro Shell.
