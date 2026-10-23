// Task 55: diff for a commit, compare or PR, for the diff viewer (task 58)
// Input: { target, id } + { kind: "commit", sha } | { kind: "compare", base, head } | { kind: "pull", number }
// If kind is omitted for a question, its diffRef is used
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { githubFetch, assertRef } from "./client";
import { resolveLinkedRepo } from "./access";
import { REGION, MAX_PATCH_CHARS_PER_FILE, MAX_PATCH_CHARS_TOTAL, MAX_PR_FILE_PAGES } from "./config";

interface GitHubFile {
  filename: string;
  previous_filename?: string;
  status: string;
  additions: number;
  deletions: number;
  patch?: string;
}

type DiffRef =
  | { kind: "commit"; sha: string }
  | { kind: "compare"; base: string; head: string }
  | { kind: "pull"; number: number };

function parseDiffRef(raw: Record<string, unknown> | null): DiffRef {
  if (!raw) throw new HttpsError("invalid-argument", "Say which commit, comparison or pull request to show.");
  switch (raw.kind) {
    case "commit":
      return { kind: "commit", sha: assertRef(raw.sha, "sha") };
    case "compare":
      return { kind: "compare", base: assertRef(raw.base, "base"), head: assertRef(raw.head, "head") };
    case "pull": {
      const n = raw.number;
      if (typeof n !== "number" || !Number.isInteger(n) || n < 1) {
        throw new HttpsError("invalid-argument", "number must be a pull request number.");
      }
      return { kind: "pull", number: n };
    }
    default:
      throw new HttpsError("invalid-argument", "kind must be commit, compare or pull.");
  }
}

export const getGitHubDiff = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const repo = await resolveLinkedRepo(request.data);
  const input = (request.data ?? {}) as Record<string, unknown>;
  const ref = parseDiffRef(input.kind !== undefined ? input : repo.diffRef);

  let files: GitHubFile[] = [];
  let title: string | null = null;
  let moreFilesOnGitHub = false;

  if (ref.kind === "commit") {
    const res = await githubFetch<{ files?: GitHubFile[]; commit: { message: string } }>(
      `${repo.repoPath}/commits/${encodeURIComponent(ref.sha)}`, repo.token);
    files = res.files ?? [];
    title = res.commit.message.split("\n")[0];
  } else if (ref.kind === "compare") {
    const res = await githubFetch<{ files?: GitHubFile[]; total_commits: number }>(
      `${repo.repoPath}/compare/${encodeURIComponent(ref.base)}...${encodeURIComponent(ref.head)}`,
      repo.token);
    files = res.files ?? [];
    title = `${ref.base}...${ref.head} (${res.total_commits} commits)`;
  } else {
    const pr = await githubFetch<{ title: string; changed_files: number }>(
      `${repo.repoPath}/pulls/${ref.number}`, repo.token);
    title = pr.title;
    for (let page = 1; page <= MAX_PR_FILE_PAGES; page++) {
      const batch = await githubFetch<GitHubFile[]>(
        `${repo.repoPath}/pulls/${ref.number}/files?per_page=100&page=${page}`, repo.token);
      files = files.concat(batch);
      if (batch.length < 100) break;
    }
    moreFilesOnGitHub = pr.changed_files > files.length;
  }

  // Cap patch sizes
  let budget = MAX_PATCH_CHARS_TOTAL;
  const shaped = files.map((f) => {
    let patch: string | null = f.patch ?? null;
    let patchTruncated = false;
    if (patch !== null) {
      const limit = Math.min(MAX_PATCH_CHARS_PER_FILE, budget);
      if (patch.length > limit) {
        patch = limit > 0 ? patch.slice(0, limit) : null;
        patchTruncated = true;
      }
      budget -= patch?.length ?? 0;
    }
    return {
      filename: f.filename,
      previousFilename: f.previous_filename ?? null,
      status: f.status,
      additions: f.additions,
      deletions: f.deletions,
      patch,
      // GitHub omits patch for binary/huge files
      patchUnavailable: f.patch === undefined,
      patchTruncated,
    };
  });

  return { kind: ref.kind, title, files: shaped, moreFilesOnGitHub };
});
