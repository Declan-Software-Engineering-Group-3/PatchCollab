// Task 52: exchange the OAuth code from the app (task 51) for a token, stored in githubTokens/{uid}
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../admin";
import { githubFetch } from "./client";
import { REGION, githubClientId, githubClientSecret } from "./config";

interface TokenResponse {
  access_token?: string;
  scope?: string;
  error?: string;
  error_description?: string;
}
interface GitHubUser { id: number; login: string; }

export const exchangeGitHubCode = onCall(
  { region: REGION, secrets: [githubClientId, githubClientSecret] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const { code, redirectUri } = request.data ?? {};
    if (typeof code !== "string" || code.length === 0 || code.length > 200) {
      throw new HttpsError("invalid-argument", "code is required.");
    }
    if (redirectUri !== undefined && typeof redirectUri !== "string") {
      throw new HttpsError("invalid-argument", "redirectUri must be a string.");
    }

    // GitHub returns 200 with an error field for a bad code
    const tokenRes = await githubFetch<TokenResponse>(
      "https://github.com/login/oauth/access_token",
      null,
      {
        method: "POST",
        body: JSON.stringify({
          client_id: githubClientId.value(),
          client_secret: githubClientSecret.value(),
          code,
          ...(redirectUri ? { redirect_uri: redirectUri } : {}),
        }),
      }
    );
    if (!tokenRes.access_token) {
      throw new HttpsError("invalid-argument",
        "The GitHub sign-in expired or was already used. Try connecting again.",
        { reason: tokenRes.error ?? "github-exchange-failed" });
    }

    const user = await githubFetch<GitHubUser>("/user", tokenRes.access_token);

    await db.collection("githubTokens").doc(uid).set({
      userId: uid,
      accessToken: tokenRes.access_token,
      scope: tokenRes.scope ?? "",
      githubUserId: user.id,
      githubUsername: user.login,
      connectedAt: FieldValue.serverTimestamp(),
    });
    await db.collection("users").doc(uid).set({ githubUsername: user.login }, { merge: true });

    return { githubUsername: user.login };
  }
);
