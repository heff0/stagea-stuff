/**
 * Stagea Auth & Permissions Abstraction
 *
 * Complies with 12-Factor (Config in environment, Attached Identity Provider).
 * Centralizes OIDC Session Verification and implements our Scoped Submodule Permissions Schema.
 */

import { AUTH_ISSUER_URL } from "astro:env/server";

// Define the available submodules in our community platform
export type Submodule = "forum" | "wiki" | "blog" | "shop" | "parts" | "shell";

// Define the permissions tiers per submodule
export type PermissionLevel =
  "admin" | "editor" | "moderator" | "user" | "guest";

// Schema representing decoded Keycloak Access Token contents
export interface KeycloakToken {
  sub: string; // Keycloak User ID
  email?: string;
  email_verified?: boolean;
  preferred_username?: string;
  name?: string;
  // Realm-level roles (typically used for global permissions)
  realm_access?: {
    roles: string[];
  };
  // Client-level roles (typically used for submodule-specific permissions)
  resource_access?: {
    [clientId: string]: {
      roles: string[];
    };
  };
  // Keycloak group memberships (injected via custom group-membership mapper)
  groups?: string[];
}

export interface UserSession {
  userId: string;
  username: string;
  email: string;
  displayName: string;
  token: string;
  roles: {
    global: string[];
    submodules: Record<Submodule, string[]>;
  };
}

/**
 * Parses and maps the Keycloak token roles to Stagea's scoped sub-site permission schema.
 */
export function parseTokenPermissions(
  tokenData: KeycloakToken,
  rawToken: string,
): UserSession {
  const globalRoles = tokenData.realm_access?.roles || [];
  const groups = tokenData.groups || [];

  // Initialize scoped submodules record
  const submodules: Record<Submodule, string[]> = {
    forum: [],
    wiki: [],
    blog: [],
    shop: [],
    parts: [],
    shell: [],
  };

  // 1. Resolve client-specific roles (Scoped submodule permissions)
  if (tokenData.resource_access) {
    Object.entries(tokenData.resource_access).forEach(([clientId, access]) => {
      const roles = access.roles || [];
      if (clientId === "forum-client") submodules.forum.push(...roles);
      if (clientId === "wiki-client") submodules.wiki.push(...roles);
      if (clientId === "blog-client") submodules.blog.push(...roles);
      if (clientId === "shop-client") submodules.shop.push(...roles);
      if (clientId === "parts-client") submodules.parts.push(...roles);
      if (clientId === "shell-client") submodules.shell.push(...roles);
    });
  }

  // 2. Map Keycloak Group memberships (Dev/Prod flexibility)
  // Global administrators automatically inherit administrative roles everywhere
  if (
    groups.includes("global-admins") ||
    globalRoles.includes("global-admin")
  ) {
    submodules.forum.push("admin");
    submodules.wiki.push("admin");
    submodules.blog.push("admin");
    submodules.shop.push("admin");
    submodules.parts.push("admin");
    submodules.shell.push("admin");
  }

  // Per-subsite admin group inheritance mappings
  if (groups.includes("forum-admins")) submodules.forum.push("admin");
  if (groups.includes("wiki-admins")) submodules.wiki.push("admin");
  if (groups.includes("blog-admins")) submodules.blog.push("admin");
  if (groups.includes("shop-admins")) submodules.shop.push("admin");

  return {
    userId: tokenData.sub,
    username: tokenData.preferred_username || "anonymous",
    email: tokenData.email || "",
    displayName:
      tokenData.name || tokenData.preferred_username || "Anonymous User",
    token: rawToken,
    roles: {
      global: globalRoles,
      submodules,
    },
  };
}

/**
 * Abstraction layer to check user privileges.
 * Supports:
 *   1. Local sub-site role delegation (e.g. user is forum moderator only).
 *   2. Global administrator delegation (e.g. user is global admin and can edit everything).
 */
export class AuthContext {
  private session: UserSession | null;

  constructor(session: UserSession | null) {
    this.session = session;
  }

  /**
   * Check if user is authenticated
   */
  public isAuthenticated(): boolean {
    return this.session !== null;
  }

  /**
   * Get the current user session
   */
  public getSession(): UserSession | null {
    return this.session;
  }

  /**
   * Core authorization check.
   * Assesses whether the current user has the required permission level for a given submodule.
   */
  public hasPermission(
    submodule: Submodule,
    requiredLevel: PermissionLevel,
  ): boolean {
    if (!this.session) {
      return requiredLevel === "guest";
    }

    const roles = this.session.roles.submodules[submodule] || [];

    // Global Admin override
    if (
      roles.includes("admin") ||
      this.session.roles.global.includes("global-admin")
    ) {
      return true;
    }

    // Role privilege hierarchy check
    switch (requiredLevel) {
      case "admin":
        return roles.includes("admin");
      case "editor":
        return roles.includes("admin") || roles.includes("editor");
      case "moderator":
        return roles.includes("admin") || roles.includes("moderator");
      case "user":
        return (
          roles.includes("admin") ||
          roles.includes("editor") ||
          roles.includes("moderator") ||
          roles.includes("user") ||
          roles.includes("member")
        );
      case "guest":
        return true;
      default:
        return false;
    }
  }
}

/**
 * OIDC Token Exchange and Verification helper
 * (Validates JWT tokens from Keycloak using our environmental context)
 */
export async function verifyOidcToken(
  rawToken: string,
): Promise<UserSession | null> {
  if (!rawToken || !AUTH_ISSUER_URL) {
    return null;
  }

  try {
    // In production, we fetch the JWKS from Keycloak to verify signature locally.
    // For scaffolding, we fetch user info from the Issuer to validate the token.
    const userInfoEndpoint = `${AUTH_ISSUER_URL}/protocol/openid-connect/userinfo`;

    const response = await fetch(userInfoEndpoint, {
      headers: {
        Authorization: `Bearer ${rawToken}`,
      },
    });

    if (!response.ok) {
      console.error(
        "[Auth] OIDC token validation failed:",
        response.statusText,
      );
      return null;
    }

    const tokenData = (await response.json()) as KeycloakToken;
    return parseTokenPermissions(tokenData, rawToken);
  } catch (error) {
    console.error("[Auth] Failed to verify OIDC token:", error);
    return null;
  }
}
