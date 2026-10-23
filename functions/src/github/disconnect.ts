// Task 62: disconnect GitHub. Revokes the token at GitHub, deletes the stored
// token, and clears the repository links on everything the student owns.
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../admin";
import { GITHUB_API, REGION, REQUEST_TIMEOUT_MS, githubClientId, githubClientSecret } from "./config";

// GitHub answers 204 with no body, which githubFetch cannot parse, so this calls fetch directly
async function revokeGrant(token: string): Promise<void> {
  const basic = Buffer.from(`${githubClientId.value()}:${githubClientSecret.value()}`).toString("base64");
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(`${GITHUB_API}/applications/${githubClientId.value()}/grant`, {
      method: "DELETE",
      headers: {
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "PatchCollab",
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ access_token: token }),
      signal: controller.signal,
    });
    // 404 means the grant is already gone, which is the outcome we want
    if (!res.ok && res.status !== 404) {
      logger.error("GitHub grant revoke failed", { status: res.status });
      throw new HttpsError("unavailable", "GitHub could not revoke the connection. Try again.",
        { reason: "github-error" });
    }
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("unavailable", "Could not reach GitHub. Try again.",
      { reason: "github-unreachable" });
  } finally {
    clearTimeout(timer);
  }
}

async function clearLinks(collection: "projects" | "questions", ownerField: string, uid: string) {
  const snap = await db.collection(collection).where(ownerField, "==", uid).get();
  const writer = db.bulkWriter();
  for (const doc of snap.docs) {
    const update: Record<string, unknown> = {};
    if (doc.get("linkedRepo") != null) update.linkedRepo = null;
    if (collection === "questions" && doc.get("diffRef") != null) update.diffRef = null;
    if (Object.keys(update).length > 0) void writer.update(doc.ref, update);
  }
  await writer.close();
}

export const disconnectGitHub = onCall(
  { region: REGION, secrets: [githubClientId, githubClientSecret] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const tokenRef = db.collection("githubTokens").doc(uid);
    const token = (await tokenRef.get()).get("accessToken");

    // Revoke first, so a failure leaves the token in place and the student can retry
    if (typeof token === "string" && token.length > 0) await revokeGrant(token);

    await clearLinks("projects", "ownerId", uid);
    await clearLinks("questions", "userId", uid);
    await tokenRef.delete();
    await db.collection("users").doc(uid).set({ githubUsername: FieldValue.delete() }, { merge: true });
    return {};
  }
);
