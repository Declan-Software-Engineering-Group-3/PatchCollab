// GitHub integration config (task list section 8)
import { defineSecret } from "firebase-functions/params";

export const REGION = "africa-south1";

// Task 49: OAuth App credentials. firebase functions:secrets:set GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET
// Emulator: put both in functions/.secret.local
export const githubClientId = defineSecret("GITHUB_CLIENT_ID");
export const githubClientSecret = defineSecret("GITHUB_CLIENT_SECRET");

// Public repos only until private repo access is cleared with the supervisor (ethics, 8.2)
export const PUBLIC_REPOS_ONLY = true;

export const GITHUB_API = "https://api.github.com";
export const REQUEST_TIMEOUT_MS = 10_000;

// Response size limits
export const MAX_TREE_ENTRIES = 5000;
export const MAX_FILE_CHARS = 200_000;
export const MAX_PATCH_CHARS_PER_FILE = 100_000;
export const MAX_PATCH_CHARS_TOTAL = 500_000;
export const MAX_PR_FILE_PAGES = 3; // 100 files per page
