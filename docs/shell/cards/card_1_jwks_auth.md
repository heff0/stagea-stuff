# Sprint Card 1: Local OIDC JWKS Token Verification

## 🎯 1. Overview & Business Case
To maintain absolute security and high performance, the Astro Shell (the Edge) must verify client OpenID Connect (OIDC) JWT tokens issued by Keycloak. Calling Keycloak's `/protocol/openid-connect/userinfo` on *every* request introduces severe latency bottlenecks and external network dependencies. 

This card details the requirements to implement **local cryptographic JWT signature verification** utilizing Keycloak's JSON Web Key Set (JWKS) endpoint.

---

## 🛠 2. Technical Solution & Code Blueprint
We will use the ultra-lightweight, zero-dependency, edge-compatible library `jose` to cache Keycloak public signing keys and verify incoming JWT signatures locally in memory.

### Required Dependency
```json
// shell/package.json
"dependencies": {
  "jose": "^5.6.3"
}
```

### Verification Logic Blueprint
Refactor the token validation helper in `shell/src/lib/auth.ts`:

```typescript
import * as jose from "jose";
import { AUTH_ISSUER_URL, AUTH_CLIENT_ID } from "astro:env/server";

// Cache JWKS client instance in-memory to reuse public keys across requests
let jwksKeyStore: ReturnType<typeof jose.createRemoteJWKSet> | null = null;

export async function verifyOidcTokenLocal(rawToken: string): Promise<UserSession | null> {
  if (!rawToken || !AUTH_ISSUER_URL) {
    return null;
  }

  try {
    // 1. Initialize remote JWKS keystore if cached instance is empty
    if (!jwksKeyStore) {
      const jwksUrl = new URL("/protocol/openid-connect/certs", AUTH_ISSUER_URL).toString();
      jwksKeyStore = jose.createRemoteJWKSet(new URL(jwksUrl), {
        cooldownDuration: 30000, // Rate-limit key fetching to once per 30s
        timeoutDuration: 2000    // Timeout JWKS download after 2s
      });
    }

    // 2. Cryptographically verify signature, expiry (exp), and payload structure
    const { payload } = await jose.jwtVerify(rawToken, jwksKeyStore, {
      issuer: AUTH_ISSUER_URL,
      audience: AUTH_CLIENT_ID
    });

    // 3. Cast decoded payload to KeycloakToken contract and resolve permission roles
    const tokenData = payload as unknown as KeycloakToken;
    return parseTokenPermissions(tokenData, rawToken);

  } catch (error) {
    console.error("[Auth] Local cryptographical JWT verification failed:", error);
    return null; // Graceful rejection
  }
}
```

---

## 📋 3. MVP Acceptance Criteria
1. Token validation occurs **locally** inside the server memory; no outbound `/userinfo` request is made after keys are cached.
2. Expired tokens (`exp`) are rejected cryptographically.
3. Invalid signatures, incorrect issuers, or mismatched audiences are blocked instantly.
4. Keycloak signing key rotation is handled dynamically via `cooldownDuration` fetch refreshes.

---

## 🚦 4. 6-Step Feature Loop Checklist
- [ ] **1. Scaffold**: Create a test JWT token mock utility in `shell/src/test/mocks.ts`.
- [ ] **2. Document**: Update the [Shell Auth Plan](../auth_plan.md) with the new cryptographical local verification protocol.
- [ ] **3. MVP Spec**: Formulate validation edge cases (expired tokens, altered signatures).
- [ ] **4. Test**: Write a unit test asserting that `verifyOidcTokenLocal` cleanly returns `null` for altered payloads.
- [ ] **5. Implement**: Install `jose`, write the dynamic JWKS keystore caching logic, and connect it to `src/pages/account/dashboard.astro`.
- [ ] **6. Review**: Run `pnpm check && pnpm build` to verify compilation.
