/**
 * Federated Search Abstraction
 *
 * Complies with 12-Factor (Treating backing services as attached resources).
 * Queries NodeBB, MediaWiki, Ghost, and Saleor APIs in parallel using
 * environment-injected endpoints, returning a normalized search result set.
 */

import { FORUM_URL, WIKI_URL, BLOG_URL, SHOP_URL } from "astro:env/server";

export type SearchSource = "forum" | "wiki" | "blog" | "shop";

export interface SearchResult {
  id: string;
  title: string;
  url: string;
  snippet: string;
  source: SearchSource;
  publishedAt?: string;
  imageUrl?: string;
  price?: string; // Specific to shop products
}

/**
 * Normalizes results from the NodeBB (Forum) Search API.
 */
async function searchForum(query: string): Promise<SearchResult[]> {
  if (!FORUM_URL) return [];
  try {
    // NodeBB Search API endpoint: /api/search?term=...
    const url = new URL("/api/search", FORUM_URL);
    url.searchParams.set("term", query);

    const response = await fetch(url.toString(), {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(3000), // 3s timeout for robustness (12-factor disposability)
    });

    if (!response.ok) return [];
    const data = await response.json();

    // NodeBB structures results in data.posts or data.topics
    const posts = data.posts || [];
    return posts.slice(0, 5).map((post: any) => ({
      id: `forum-${post.pid}`,
      title: post.topic?.title || "Forum Post",
      url: new URL(`/post/${post.pid}`, FORUM_URL).toString(),
      snippet: post.content
        ? post.content.replace(/<[^>]*>/g, "").substring(0, 160) + "..."
        : "",
      source: "forum" as const,
      publishedAt: post.timestampISO,
    }));
  } catch (error) {
    console.warn("[Search] Forum search offline/failed:", error);
    return []; // Graceful fallback
  }
}

/**
 * Normalizes results from the MediaWiki API.
 */
async function searchWiki(query: string): Promise<SearchResult[]> {
  if (!WIKI_URL) return [];
  try {
    // MediaWiki action API: /api.php?action=query&list=search&srsearch=...&format=json
    const url = new URL("api.php", WIKI_URL);
    url.searchParams.set("action", "query");
    url.searchParams.set("list", "search");
    url.searchParams.set("srsearch", query);
    url.searchParams.set("format", "json");
    url.searchParams.set("utf8", "1");

    const response = await fetch(url.toString(), {
      signal: AbortSignal.timeout(3000),
    });

    if (!response.ok) return [];
    const data = await response.json();

    const searchResults = data.query?.search || [];
    return searchResults.slice(0, 5).map((item: any) => ({
      id: `wiki-${item.pageid}`,
      title: item.title,
      // URL pattern typically: index.php?title=Page_Name
      url: new URL(
        `index.php?title=${encodeURIComponent(item.title)}`,
        WIKI_URL,
      ).toString(),
      snippet: item.snippet
        ? item.snippet.replace(/<[^>]*>/g, "").replace(/&quot;/g, '"') + "..."
        : "",
      source: "wiki" as const,
      publishedAt: item.timestamp,
    }));
  } catch (error) {
    console.warn("[Search] Wiki search offline/failed:", error);
    return [];
  }
}

/**
 * Normalizes results from the Ghost (Blog) Content API.
 */
async function searchBlog(query: string): Promise<SearchResult[]> {
  if (!BLOG_URL) return [];
  try {
    // Ghost Content API endpoint: /ghost/api/content/posts/?key=...&filter=title:like:...
    // Requires a Ghost Content API key, typically read from the environment
    const ghostKey = import.meta.env.GHOST_CONTENT_API_KEY || "placeholder_key";
    const url = new URL("/ghost/api/content/posts/", BLOG_URL);
    url.searchParams.set("key", ghostKey);
    url.searchParams.set("limit", "5");
    url.searchParams.set(
      "filter",
      `title:~'${query}',custom_excerpt:~'${query}'`,
    );

    const response = await fetch(url.toString(), {
      signal: AbortSignal.timeout(3000),
    });

    if (!response.ok) return [];
    const data = await response.json();

    const posts = data.posts || [];
    return posts.map((post: any) => ({
      id: `blog-${post.id}`,
      title: post.title,
      url: post.url || new URL(post.slug, BLOG_URL).toString(),
      snippet: post.custom_excerpt || post.excerpt || "",
      source: "blog" as const,
      publishedAt: post.published_at,
      imageUrl: post.feature_image,
    }));
  } catch (error) {
    console.warn("[Search] Blog search offline/failed:", error);
    return [];
  }
}

/**
 * Normalizes results from the Saleor (Shop) Storefront GraphQL API.
 */
async function searchShop(query: string): Promise<SearchResult[]> {
  if (!SHOP_URL) return [];
  try {
    // Saleor typically has its GraphQL endpoint at /graphql/ (configured in env)
    // We send a standard GraphQL query to search products
    const graphqlQuery = {
      query: `
        query SearchProducts($search: String!) {
          products(search: $search, first: 5, channel: "default-channel") {
            edges {
              node {
                id
                name
                slug
                description
                thumbnail {
                  url
                }
                pricing {
                  priceRange {
                    start {
                      gross {
                        amount
                        currency
                      }
                    }
                  }
                }
              }
            }
          }
        }
      `,
      variables: { search: query },
    };

    const response = await fetch(SHOP_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(graphqlQuery),
      signal: AbortSignal.timeout(3000),
    });

    if (!response.ok) return [];
    const json = await response.json();
    const edges = json.data?.products?.edges || [];

    return edges.map(({ node }: any) => {
      const priceData = node.pricing?.priceRange?.start?.gross;
      const priceString = priceData
        ? `${priceData.amount} ${priceData.currency}`
        : undefined;

      // Try parsing description from JSON structure (Saleor description is draftjs rich text)
      let snippet = "";
      try {
        const descObj = JSON.parse(node.description);
        snippet = descObj.blocks?.[0]?.text || "";
      } catch {
        snippet = node.description || "";
      }

      return {
        id: `shop-${node.id}`,
        title: node.name,
        url: new URL(`/products/${node.slug}`, SHOP_URL).toString(),
        snippet: snippet.substring(0, 160) + "...",
        source: "shop" as const,
        imageUrl: node.thumbnail?.url,
        price: priceString,
      };
    });
  } catch (error) {
    console.warn("[Search] Shop search offline/failed:", error);
    return [];
  }
}

/**
 * Master execution method: executes search across all 4 backing platforms
 * in parallel and returns aggregated results.
 */
export async function runFederatedSearch(
  query: string,
): Promise<SearchResult[]> {
  const sanitizedQuery = query.trim();
  if (!sanitizedQuery) return [];

  // Fire off all searches concurrently (Factor VIII: Scale & Concurrency, Factor IV: Independent Backing Resources)
  const [forumResults, wikiResults, blogResults, shopResults] =
    await Promise.all([
      searchForum(sanitizedQuery),
      searchWiki(sanitizedQuery),
      searchBlog(sanitizedQuery),
      searchShop(sanitizedQuery),
    ]);

  // Aggregate results and interleave or return grouped
  return [...blogResults, ...shopResults, ...forumResults, ...wikiResults];
}
