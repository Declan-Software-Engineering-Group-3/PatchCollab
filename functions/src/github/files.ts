// Task 54: repo file tree and single file contents. Input: { target, id, ref? }
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { githubFetch, encodePath, assertRef } from "./client";
import { resolveLinkedRepo } from "./access";
import { REGION, MAX_TREE_ENTRIES, MAX_FILE_CHARS } from "./config";

interface TreeResponse {
  truncated: boolean;
  tree: { path: string; type: "blob" | "tree" | "commit"; size?: number }[];
}

export const getGitHubTree = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const repo = await resolveLinkedRepo(request.data);
  const ref = request.data?.ref === undefined ? repo.defaultBranch : assertRef(request.data.ref, "ref");

  const res = await githubFetch<TreeResponse>(
    `${repo.repoPath}/git/trees/${encodeURIComponent(ref)}?recursive=1`, repo.token);

  const entries = res.tree
    .filter((e) => e.type === "blob" || e.type === "tree")
    .map((e) => ({ path: e.path, type: e.type === "blob" ? "file" : "dir", size: e.size ?? null }));

  return {
    owner: repo.owner,
    name: repo.name,
    ref,
    truncated: res.truncated || entries.length > MAX_TREE_ENTRIES,
    entries: entries.slice(0, MAX_TREE_ENTRIES),
  };
});

interface ContentResponse {
  type: string;
  path: string;
  size: number;
  sha: string;
  encoding?: string;
  content?: string;
}

export const getGitHubFile = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const repo = await resolveLinkedRepo(request.data);

  const path = request.data?.path;
  if (typeof path !== "string" || path.length === 0 || path.length > 1000 ||
      path.split("/").some((seg: string) => seg === "" || seg === "." || seg === "..")) {
    throw new HttpsError("invalid-argument", "path must be a file path inside the repository.");
  }
  const ref = request.data?.ref === undefined ? repo.defaultBranch : assertRef(request.data.ref, "ref");

  const res = await githubFetch<ContentResponse | ContentResponse[]>(
    `${repo.repoPath}/contents/${encodePath(path)}?ref=${encodeURIComponent(ref)}`, repo.token);

  if (Array.isArray(res) || res.type !== "file") {
    throw new HttpsError("invalid-argument", "That path is a folder, not a file.");
  }

  const base = { path: res.path, ref, size: res.size, sha: res.sha };

  // GitHub returns no content for files over 1 MB
  if (res.encoding !== "base64" || !res.content) {
    return { ...base, content: null, binary: false, tooLarge: true, truncated: false };
  }

  const text = Buffer.from(res.content, "base64").toString("utf8");
  if (text.includes("\u0000")) {
    return { ...base, content: null, binary: true, tooLarge: false, truncated: false };
  }
  return {
    ...base,
    content: text.slice(0, MAX_FILE_CHARS),
    binary: false,
    tooLarge: false,
    truncated: text.length > MAX_FILE_CHARS,
  };
});
