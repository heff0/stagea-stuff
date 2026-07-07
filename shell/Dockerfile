# Multi-stage Dockerfile for Stagea Astro Shell
# Following 12-factor principles: Explicit dependencies, isolated builds,
# stateless processes, non-root user execution, and fast startup/disposability.

# --- Build Stage ---
FROM node:22-alpine AS builder

# Set working directory
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@10.30.0

# Copy package configuration and lockfile
COPY package.json pnpm-lock.yaml ./

# Install dependencies (frozen-lockfile for deterministic builds)
RUN pnpm install --frozen-lockfile

# Copy source code and config files
COPY astro.config.mjs tsconfig.json ./
COPY src/ ./src/
COPY public/ ./public/

# Build the Astro site for SSR Node deployment
RUN pnpm build

# --- Production Runner Stage ---
FROM node:22-alpine AS runner

# Set production environment
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=4321

WORKDIR /app

# Install pnpm for production package resolution
RUN npm install -g pnpm@10.30.0

# Use non-root node user for security (unprivileged execution)
RUN chown -R node:node /app
USER node

# Copy build output, package.json, and production-only dependencies
COPY --chown=node:node --from=builder /app/dist/ ./dist/
COPY --chown=node:node --from=builder /app/package.json ./
COPY --chown=node:node --from=builder /app/pnpm-lock.yaml ./

# Install only production dependencies to keep the image slim
RUN pnpm install --prod --frozen-lockfile

# Expose the configured port
EXPOSE 4321

# Start the standalone Astro Node.js server
CMD ["node", "./dist/server/entry.mjs"]
