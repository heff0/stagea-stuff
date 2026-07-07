# Astro Shell — 12-Factor Implementation Plan

This document audits the Astro Shell (`shell/`) against the twelve principles of [12factor.net](https://12factor.net). It identifies compliance levels, highlights operational gaps, and provides an actionable engineering path to make the Shell 100% production-ready.

---

## 1. Executive Summary

| Factor | Description | Current Status | Compliance Rating | Key Action Items |
| :--- | :--- | :--- | :--- | :--- |
| **I. Codebase** | One codebase, many deploys | **Compliant** | 🟢 100% | Managed in central monorepo, versioned cleanly. |
| **II. Dependencies**| Explicitly declare/isolate | **Compliant** | 🟢 100% | Driven by pnpm-lock, isolated in multi-stage Docker build. |
| **III. Config** | Store config in the env | **Compliant** | 🟢 100% | Wired to typed Astro Env Schema, zero hardcoded configs. |
| **IV. Backing Services**| Treat as attached resources | **Compliant** | 🟢 100% | Sub-sites decoupled; handles offline services gracefully. |
| **V. Build, Release, Run**| Strict stage separation | **Partial** | 🟡 80% | Build/run separated via Docker. Need Release pipeline spec. |
| **VI. Processes** | Stateless execution | **Compliant** | 🟢 100% | Stateless cookies and local in-memory session mapping. |
| **VII. Port Binding**| Export services via port | **Compliant** | 🟢 100% | Standalone Node.js server binding natively to `:4321`. |
| **VIII. Concurrency**| Scale out via process model | **Compliant** | 🟢 100% | Scaling is as simple as launching parallel containers. |
| **IX. Disposability**| Fast startup/graceful exit | **Partial** | 🟡 75% | Image size optimized. Need explicit SIGTERM Node handlers. |
| **X. Dev/Prod Parity**| Keep envs highly similar | **Compliant** | 🟢 100% | Same Dockerfile/Compose used locally and in production. |
| **XI. Logs** | Treat logs as event streams | **Compliant** | 🟢 100% | Output streamed to stdout/stderr. No disk log-writing. |
| **XII. Admin Procs**| Run admin tasks as one-offs | **Planned** | 🔴 30% | Scaffolded mockup. Need shell task scripts in repository. |

---

## 2. Factor-by-Factor Audit & Improvement Path

---

### I. Codebase
> One codebase tracked in revision control, many deploys.
* **Current State**: The Shell exists as a dedicated root directory in the Stagea monorepo. The codebase is identical across all runs.
* **Improvement Path**: 
  * Ensure our CI/CD pipeline tags successful commits with semantic release versions (e.g. `v1.0.1-rc3`).
  * Enforce branch protection on `main` to prevent direct push.

---

### II. Dependencies
> Explicitly declare and isolate dependencies.
* **Current State**: Declared in `package.json`, locked in `pnpm-lock.yaml`. Our multi-stage `Dockerfile` executes a clean, locked dependency restore (`pnpm install --frozen-lockfile`) inside an isolated, minimal Alpine environment.
* **Improvement Path**:
  * Set up automated dependency audits (e.g. `pnpm audit` or Dependabot) in GitHub Actions to catch security vulnerabilities in third-party libraries.

---

### III. Config
> Store config in the environment.
* **Current State**: Complete compliance. All environment variables for the shell's edge operations are declared and strictly typed inside `astro.config.mjs` under `env.schema`. Defaults are provided exclusively for frictionless local development.
* **Improvement Path**:
  * Ensure staging and production deployments completely restrict default fallbacks and flag missing critical configs (like `AUTH_CLIENT_SECRET`) as fatal errors during the container release phase.

---

### IV. Backing Services
> Treat backing services as attached resources.
* **Current State**: All upstream nodes (forum, wiki, blog, shop) are treated as attached network targets configured via environment variables. Our federated search and page routers recover gracefully with fallback layouts if any submodule is unreachable.
* **Improvement Path**:
  * Implement an internal DNS routing mechanism (e.g. using docker-compose service names inside internal bridge networks or Consul in production) to decouple dependencies on public URLs for server-to-server operations.

---

### V. Build, Release, Run
> Strictly separate build and run stages.
* **Current State**: Build and run are isolated inside the `Dockerfile` stages. However, we lack a release tracking pipeline.
* **Improvement Path**:
  * **Build Step**: Triggered by git commit, producing a zipped release bundle or an immutable Docker image tagged with the commit SHA.
  * **Release Step**: Combine the image tag with the target environment configuration (environment variables) and store the deployment manifest in a release registry (e.g., using ArgoCD or Portainer release records) to facilitate instant rollbacks.
  * **Run Step**: Run the container using standard execution tools. Prevent any console configuration edits on a running container.

---

### VI. Processes
> Execute the app as one or more stateless processes.
* **Current State**: The Astro Shell runs as a share-nothing stateless process. Session tokens are checked server-side and cached in transient request memory, storing persistent claims in encrypted browser cookies.
* **Improvement Path**:
  * When scaling the Shell to multiple parallel processes behind our edge proxy, swap our local filesystem session storage adapter for an external distributed Redis cache to manage stateful OIDC tokens at high concurrency scales.

---

### VII. Port Binding
> Export services via port binding.
* **Current State**: The Shell is self-contained. It binds directly to the environment-configured `PORT` (defaults to `4321`) utilizing Astro's built-in standalone Node adapter, completely removing the dependency on an external server wrapper.
* **Improvement Path**:
  * Ensure that local, staging, and production network routers only speak to the Shell through this port interface, allowing unified edge routing (e.g. Nginx proxying port `80/443` down to `4321` internally).

---

### VIII. Concurrency
> Scale out via the process model.
* **Current State**: Fully compliant. Since the Astro process is stateless, scaling up web traffic handling is achieved by launching multiple parallel instances of the `stagea-shell` container behind a load balancer.
* **Improvement Path**:
  * Establish container scaling rules in the staging/production compose clusters (e.g. using `docker compose up --scale shell=3` or Kubernetes replica bounds) to distribute HTTP loads automatically.

---

### IX. Disposability
> Maximize robustness with fast startup and graceful shutdown.
* **Current State**: The Alpine Node container starts up in milliseconds. However, our standalone Node entrypoint lacks robust `SIGTERM` interception handlers, meaning sudden container terminations could sever active HTTP requests.
* **Improvement Path**:
  * Wrap our Node.js runtime process launcher or write a thin middleware script in the entrypoint to explicitly capture system `SIGTERM` signals. This will allow the Astro server to stop accepting new requests, finish serving active connections, and exit cleanly within a 10-second timeout window.

---

### X. Dev/Prod Parity
> Keep development, staging, and production as similar as possible.
* **Current State**: Very high parity. We use the same Docker images and configuration files locally as we do on staging. Backing services (like Postgres or Redis) are run natively in local containers instead of mocking.
* **Improvement Path**:
  * Ensure our automated CI test suites run within the exact same docker-compose configuration as development to catch environment configuration discrepancies immediately.

---

### XI. Logs
> Treat logs as event streams.
* **Current State**: No internal logging files are created. All Astro server outputs and system runtime errors are streamed directly to `stdout` and `stderr`.
* **Improvement Path**:
  * Set up a centralized logging driver in our docker-compose orchestration (such as `loki` or `gelf`) to capture these event streams from the Docker daemon and index them for debugging.

---

### XII. Admin Processes
> Run admin/management tasks as one-off processes.
* **Current State**: We have created a mockup interface in the Administration View. However, we do not have automated, version-controlled scripts for actual database migration or cache purging tasks.
* **Improvement Path**:
  * Create a `shell/scripts/` directory in our repository to house administrative and maintenance scripts (e.g. database schema migrations, admin user seed scripts).
  * Run these scripts exclusively as one-off commands inside isolated containers (e.g. `docker compose run --rm shell-admin pnpm migrate`) rather than bundling them into the web server startup process.

---

## 🔗 Related Documentation & Compliance References

* 🧭 **[Platform Master Site-Plan](../site-plan.md)** — Overall multi-site architecture, subdomain map, and current monorepo statuses.
* ⭐️ **[System 12-Factor Compliance Audit](../12_factor_compliance.md)** — Comprehensive review of Stagea monorepo compliance with all twelve principles from 12factor.net.
* 🚦 **[Shell Quality Readiness Ratings](./READINESS_RATING.md)** — Per-file quality assessments, typescript audits, and production path for the Astro Shell.
* 🔐 **[Shell Scoped Auth Plan](./auth_plan.md)** — Centralized authentication, Keycloak clients, and role hierarchy mappings.
* 📋 **[Shell Sprint Backlog & TODO](./TODO.md)** — Active product features backlog and our 6-step vertical loop checklist.
