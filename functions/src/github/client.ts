// Task 56: GitHub API wrapper. Maps GitHub errors to HttpsErrors with a reason code
// the app can check (e.g. github-token-invalid -> show reconnect).
import { HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { GITHUB_API, REQUEST_TIMEOUT_MS } from "./config";

async function throwForStatus(res: Response, url: string): Promise<never> {
  const status = res.status;

  if (status === 401) {
    throw new HttpsError("failed-precondition",
      "Your GitHub connection has expired. Reconnect GitHub and try again.",
      { reason: "github-token-invalid" });
  }

  if (status === 403 || status === 429) {
    const remaining = res.headers.get("x-ratelimit-remaining");
    const retryAfter = res.headers.get("retry-after");
    if (status === 429 || remaining === "0" || retryAfter !== null) {
      const resetEpoch = Number(res.headers.get("x-ratelimit-reset") ?? 0);
      const resetAt = resetEpoch > 0
        ? new Date(resetEpoch * 1000).toISOString()
        : retryAfter !== null
          ? new Date(Date.now() + Number(retryAfter) * 1000).toISOString()
          : null;
      throw new HttpsError("resource-exhausted",
        "GitHub's rate limit was reached. Try again in a few minutes.",
        { reason: "github-rate-limited", resetAt });
    }
    throw new HttpsError("permission-denied",
      "GitHub refused access to this repository.",
      { reason: "github-forbidden" });
  }

  if (status === 404) {
    throw new HttpsError("not-found",
      "Repository or file not found. It may be private or deleted.",
      { reason: "github-not-found" });
  }

  if (status === 409 || status === 422) {
    throw new HttpsError("invalid-argument",
      "GitHub could not find that commit, branch or pull request, or the repository is empty.",
      { reason: "github-bad-ref" });
  }

  logger.error("Unexpected GitHub response", { url, status });
  throw new HttpsError("unavailable", "GitHub returned an unexpected error. Try again.",
    { reason: "github-error" });
}

export async function githubFetch<T>(
  pathOrUrl: string,
  token: string | null,
  init: { method?: string; body?: string } = {}
): Promise<T> {
  const url = pathOrUrl.startsWith("https://") ? pathOrUrl : `${GITHUB_API}${pathOrUrl}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let res: Response;
  try {
    const headers: Record<string, string> = {
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "PatchCollab",
    };
    if (token) headers.Authorization = `Bearer ${token}`;
    if (init.body !== undefined) headers["Content-Type"] = "application/json";
    res = await fetch(url, { method: init.method ?? "GET", body: init.body, headers, signal: controller.signal });
  } catch (err) {
    if ((err as Error).name === "AbortError") {
      throw new HttpsError("deadline-exceeded", "GitHub took too long to respond. Try again.",
        { reason: "github-timeout" });
    }
    logger.error("Could not reach GitHub", { url, err });
    throw new HttpsError("unavailable", "Could not reach GitHub. Try again.",
      { reason: "github-unreachable" });
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) return throwForStatus(res, url);
  return (await res.json()) as T;
}

// Encode each path segment, keep the slashes
export function encodePath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}

const NAME_PATTERN = /^[A-Za-z0-9_.-]{1,100}$/;
export function assertRepoName(value: unknown, label: string): string {
  if (typeof value !== "string" || !NAME_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", `${label} is not a valid GitHub name.`);
  }
  return value;
}

export function assertRef(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 255 || value.includes("..")) {
    throw new HttpsError("invalid-argument", `${label} is not a valid branch, tag or commit.`);
  }
  return value;
}
