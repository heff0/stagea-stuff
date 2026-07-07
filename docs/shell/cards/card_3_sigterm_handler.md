# Sprint Card 3: Node.js Graceful SIGTERM Handling

## 🎯 1. Overview & Business Case
Following **Factor IX (Disposability)**, applications must maximize robustness with fast startup and graceful shutdown. During rolling cluster deployments, scaling triggers, or server maintenance, the orchestrator issues a `SIGTERM` signal to stop running container processes.

If our Node.js runtime fails to catch this signal, the container will instantly exit, severing open browser connections, and resulting in failed requests (HTTP 502/504 errors at the edge). 

This card covers implementing an explicit signal handler to gracefully drain, close, and shut down Astro SSR web nodes.

---

## 🛠 2. Technical Solution & Code Blueprint
We will configure Astro’s standalone Node server to catch `SIGTERM` and `SIGINT` signals, stop accepting new network connections, let active HTTP requests finish processing, and close all connection pools cleanly before exiting.

Since the `@astrojs/node` standalone adapter generates a pre-compiled entrypoint, we will wrap our server execution with a custom node server wrapper at `shell/src/server.mjs`.

### Custom Server Launcher (`shell/src/server.mjs`)
Create the custom launcher script:

```javascript
import { handler as ssrHandler } from '../dist/server/entry.mjs';
import express from 'express';
import http from 'http';

const app = express();
const port = process.env.PORT || 4321;
const host = process.env.HOST || '0.0.0.0';

// Register the compiled Astro SSR middleware
app.use(ssrHandler);

const server = http.createServer(app);

// Keep track of open connections for fast socket draining
const activeSockets = new Set();
server.on('connection', (socket) => {
  activeSockets.add(socket);
  socket.on('close', () => activeSockets.delete(socket));
});

server.listen(port, host, () => {
  console.log(`[Astro Server] Running on http://${host}:${port}`);
});

// Intercept SIGTERM and SIGINT (Factor IX Graceful Disposability)
const handleGracefulShutdown = (signal) => {
  console.log(`[Shutdown] Intercepted ${signal}. Initiating graceful exit sequence...`);
  
  // 1. Tell the HTTP server to stop accepting new network connections
  server.close(() => {
    console.log('[Shutdown] All active connections drained. Server exited cleanly.');
    process.exit(0);
  });

  // 2. Allow active connections up to a 10s grace period to finish in-flight payloads
  setTimeout(() => {
    console.warn('[Shutdown] Force-closing outstanding open connections due to grace timeout...');
    for (const socket of activeSockets) {
      socket.destroy();
    }
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => handleGracefulShutdown('SIGTERM'));
process.on('SIGINT', () => handleGracefulShutdown('SIGINT'));
```

### Update the Startup Command in `shell/package.json`
Redirect the run script to execute our graceful launcher wrapper:
```json
"scripts": {
  "start": "node ./src/server.mjs"
}
```

---

## 📋 3. MVP Acceptance Criteria
1. The server catches system `SIGTERM` and `SIGINT` signals cleanly without crashing.
2. New connection attempts are blocked immediately after the signal is received.
3. Active, open connections are given up to 10 seconds to finish transmitting.
4. The server closes database pool handlers and exits with code `0`.

---

## 🚦 4. 6-Step Feature Loop Checklist
- [ ] **1. Scaffold**: Create the custom wrapper script `shell/src/server.mjs` and change `package.json` execution vectors.
- [ ] **2. Document**: Update the [12-Factor Implementation Plan](../../12_FACTOR_PLAN.md) detailing SIGTERM draining protocols.
- [ ] **3. MVP Spec**: Formulate target socket destruction limits and close timers.
- [ ] **4. Test**: Run `docker run`, send a `kill -15` to the PID, and check if the process logs graceful exit lines and shuts down.
- [ ] **5. Implement**: Write signal listener catchers, bind active socket tracking sets, and write dynamic Express handlers.
- [ ] **6. Review**: Verify that the server compiles and builds seamlessly using `pnpm build`.
