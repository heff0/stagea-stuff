# Sprint Card 6: Docker Container Sizing Limits

## 🎯 1. Overview & Business Case
To guarantee the operational stability of the host machine in local development and staging environments, we must implement strict container resource allocation boundaries. In highly containerized monorepos, a single unconstrained memory leak or infinite loop inside a microservice can consume 100% of host CPU and RAM, freezing the developer's workstation or crashing the staging cluster.

This card defines the requirements and configuration schemas to implement **resource allocation quotas** (limits and reservations) on our Docker Compose service stack.

---

## 🛠 2. Technical Solution & Code Blueprint
We will update our Docker Compose configurations (such as `shell/docker-compose.yml` and root orchestrators) to register strict memory and CPU utilization caps.

### Docker Compose Resource Quotation Blueprint
Modify `shell/docker-compose.yml` to inject the resource boundaries under the `deploy` sub-property. This ensures the Docker engine schedules and limits the container natively:

```yaml
# shell/docker-compose.yml
version: "3.8"

services:
  shell:
    image: stagea-shell
    build:
      context: .
      dockerfile: Dockerfile
    container_name: stagea-shell
    ports:
      - "4321:4321"
    environment:
      - NODE_ENV=production
      - HOST=0.0.0.0
      - PORT=4321
    restart: unless-stopped
    
    # Resource boundaries (Factor VIII Concurrency, Factor X Dev/Prod Parity)
    deploy:
      resources:
        limits:
          cpus: '0.50'     # Strictly cap the container to use maximum 50% of 1 CPU core
          memory: 512M     # strictly cap the container to maximum 512MB RAM
        reservations:
          cpus: '0.10'     # Guarantee reservation of 10% of 1 CPU core
          memory: 128M     # Guarantee reservation of 128MB RAM
```

*Note on Memory Limits: If Node.js attempts to allocate heap memory beyond the 512MB quota limit, the Docker daemon will instantly trigger an out-of-memory (OOM) killer on that container, terminating it. Because we have configured `restart: unless-stopped` (Factor IX: Disposability), Docker will immediately spin up a fresh, healthy, leak-free container within milliseconds, preventing downtime!*

---

## 📋 3. MVP Acceptance Criteria
1. The container runs with strict CPU resource boundaries (capped to max 50% CPU of a single core).
2. The container runs with strict RAM utilization caps (capped to max 512MB RAM).
3. If an out-of-memory event is triggered (e.g. heap exhaustion), the process is immediately recycled and restarted automatically by the Docker daemon.
4. Resource limits apply identically in local development environments and staging deployments to maintain dev/prod parity.

---

## 🚦 4. 6-Step Feature Loop Checklist
- [ ] **1. Scaffold**: Add `deploy.resources` definitions into `shell/docker-compose.yml`.
- [ ] **2. Document**: Record CPU/RAM boundaries and container recycling behaviors in the master [12-Factor Compliance Guide](../../12_factor_compliance.md).
- [ ] **3. MVP Spec**: Formulate target memory pools (e.g. 512MB limit / 128MB reservation) based on Astro SSR runtime weights.
- [ ] **4. Test**: Run `docker stats stagea-shell` and assert that the container's MEM LIMIT column prints `512MiB`.
- [ ] **5. Implement**: Deploy the compose file updates and test container reboot recycles.
- [ ] **6. Review**: Verify that the application continues to perform smoothly and process requests under simulated load with resource limits active.
