// Token lookup and linked repo resolution.
// GitHub reads use the linker's token (project owner or question author), not the caller's.
import { HttpsError } from "firebase-functions/v2/https";
import { db } from "../admin";
import { githubFetch, assertRepoName, encodePath } from "./client";
import { PUBLIC_REPOS_ONLY } from "./config";

export async function getStoredToken(uid: string): Promise<string> {
  const snap = await db.collection("githubTokens").doc(uid).get();
  const token = snap.exists ? snap.get("accessToken") : undefined;
  if (typeof token !== "string" || token.length === 0) {
    throw new HttpsError("failed-precondition", "GitHub is not connected for this account.",
      { reason: "github-not-connected" });
  }
  return token;
}

export interface RepoContext {
  owner: string;
  name: string;
  defaultBranch: string;
  token: string;
  repoPath: string; // "/repos/{owner}/{name}"
  diffRef: Record<string, unknown> | null;
}

interface GitHubRepo { private: boolean; default_branch: string; }

export async function resolveLinkedRepo(data: unknown): Promise<RepoContext> {
  const { target, id } = (data ?? {}) as { target?: unknown; id?: unknown };
  if (target !== "project" && target !== "question") {
    throw new HttpsError("invalid-argument", "target must be project or question.");
  }
  if (typeof id !== "string" || id.length === 0 || id.includes("/")) {
    throw new HttpsError("invalid-argument", "id is required.");
  }

  const snap = await db.collection(target === "project" ? "projects" : "questions").doc(id).get();
  if (!snap.exists) throw new HttpsError("not-found", `That ${target} does not exist.`);

  const linked = snap.get("linkedRepo") as Record<string, unknown> | null | undefined;
  if (!linked) {
    throw new HttpsError("failed-precondition", `No repository is linked to this ${target}.`,
      { reason: "no-linked-repo" });
  }
  const owner = assertRepoName(linked.owner, "Repository owner");
  const name = assertRepoName(linked.name, "Repository name");

  const linkerId = snap.get(target === "project" ? "ownerId" : "userId") as string;
  const token = await getStoredToken(linkerId);

  const repoPath = `/repos/${encodePath(owner)}/${encodePath(name)}`;
  const repo = await githubFetch<GitHubRepo>(repoPath, token);
  if (PUBLIC_REPOS_ONLY && repo.private) {
    throw new HttpsError("permission-denied",
      "PatchCollab can only show public repositories at the moment.",
      { reason: "github-private-repo" });
  }

  const diffRef = (target === "question" ? snap.get("diffRef") : null) as Record<string, unknown> | null;
  return { owner, name, defaultBranch: repo.default_branch, token, repoPath, diffRef: diffRef ?? null };
}
