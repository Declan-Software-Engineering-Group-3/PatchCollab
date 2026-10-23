// Task 53: list the user's repos for the picker (task 57)
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { githubFetch } from "./client";
import { getStoredToken } from "./access";
import { REGION, PUBLIC_REPOS_ONLY } from "./config";

const PER_PAGE = 50;

interface GitHubRepoListItem {
  name: string;
  full_name: string;
  owner: { login: string };
  default_branch: string;
  private: boolean;
  description: string | null;
  language: string | null;
  updated_at: string;
}

export const listGitHubRepos = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const page = request.data?.page ?? 1;
  if (!Number.isInteger(page) || page < 1 || page > 50) {
    throw new HttpsError("invalid-argument", "page must be a whole number from 1 to 50.");
  }

  const token = await getStoredToken(uid);
  const visibility = PUBLIC_REPOS_ONLY ? "public" : "all";
  const repos = await githubFetch<GitHubRepoListItem[]>(
    `/user/repos?per_page=${PER_PAGE}&page=${page}&sort=updated&visibility=${visibility}`,
    token
  );

  return {
    page,
    hasMore: repos.length === PER_PAGE,
    repos: repos
      .filter((r) => !PUBLIC_REPOS_ONLY || !r.private)
      .map((r) => ({
        owner: r.owner.login,
        name: r.name,
        fullName: r.full_name,
        defaultBranch: r.default_branch,
        private: r.private,
        description: r.description,
        language: r.language,
        updatedAt: r.updated_at,
      })),
  };
});
