import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../admin";
import { createAndSendNotification } from "../social/notifications";

// The owner approves or rejects a join request. Clients can't change a
// request's status or add other people as members (see firestore.rules).
export const respondToJoinRequest = onCall({ region: "africa-south1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to respond to a join request.");
  }

  const { projectId, requestId, decision } = request.data ?? {};
  if (typeof projectId !== "string" || typeof requestId !== "string" || !projectId || !requestId) {
    throw new HttpsError("invalid-argument", "projectId and requestId are required.");
  }
  if (decision !== "approved" && decision !== "rejected") {
    throw new HttpsError("invalid-argument", "decision must be approved or rejected.");
  }

  const projectRef = db.collection("projects").doc(projectId);
  const requestRef = projectRef.collection("membershipRequests").doc(requestId);

  let requesterId = "";
  let projectTitle = "";

  await db.runTransaction(async (tx) => {
    const [projectSnap, requestSnap] = await Promise.all([tx.get(projectRef), tx.get(requestRef)]);

    if (!projectSnap.exists) {
      throw new HttpsError("not-found", "Project not found.");
    }
    if (projectSnap.data()?.ownerId !== uid) {
      throw new HttpsError("permission-denied", "Only the project owner can respond to join requests.");
    }
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "Join request not found.");
    }
    if (requestSnap.data()?.status !== "pending") {
      throw new HttpsError("failed-precondition", "This request has already been answered.");
    }

    requesterId = requestSnap.data()?.userId as string;
    projectTitle = (projectSnap.data()?.title ?? "") as string;

    tx.update(requestRef, { status: decision });

    if (decision === "approved") {
      tx.set(projectRef.collection("members").doc(requesterId), {
        userId: requesterId,
        role: "member",
        joinedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  await createAndSendNotification({
    userId: requesterId,
    type: decision === "approved" ? "joinApproved" : "joinRejected",
    message:
      decision === "approved"
        ? `Your request to join "${projectTitle}" was approved.`
        : `Your request to join "${projectTitle}" was declined.`,
    relatedId: projectId,
  });

  return { projectId, requestId, status: decision };
});
