// Join requests. A student creates projects/{projectId}/membershipRequests/{requestId}
// with status "pending" (allowed by the rules). The owner is notified, then calls
// respondToMembershipRequest to approve or reject. Only this function changes status
// and adds members, as SCHEMA.md requires.
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../admin";
import { REGION } from "../config";
import { sendNotification } from "../notify";

export const onMembershipRequestCreated = onDocumentCreated(
  { document: "projects/{projectId}/membershipRequests/{requestId}", region: REGION },
  async (event) => {
    const project = await db.collection("projects").doc(event.params.projectId).get();
    if (!project.exists) return;
    await sendNotification({
      userId: project.get("ownerId"),
      type: "joinRequest",
      message: `Someone asked to join "${project.get("title")}".`,
      relatedId: event.params.projectId,
    });
  }
);

export const respondToMembershipRequest = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const { projectId, requestId, approve } = request.data ?? {};
  if (typeof projectId !== "string" || typeof requestId !== "string" || typeof approve !== "boolean") {
    throw new HttpsError("invalid-argument", "projectId, requestId and approve are required.");
  }

  const projectRef = db.collection("projects").doc(projectId);
  const requestRef = projectRef.collection("membershipRequests").doc(requestId);

  const result = await db.runTransaction(async (tx) => {
    const project = await tx.get(projectRef);
    if (!project.exists) throw new HttpsError("not-found", "Project not found.");
    if (project.get("ownerId") !== uid) {
      throw new HttpsError("permission-denied", "Only the project owner can respond.");
    }
    const req = await tx.get(requestRef);
    if (!req.exists) throw new HttpsError("not-found", "Request not found.");
    if (req.get("status") !== "pending") {
      throw new HttpsError("failed-precondition", "This request has already been answered.");
    }

    const requesterId: string = req.get("userId");
    tx.update(requestRef, { status: approve ? "approved" : "rejected" });
    if (approve) {
      tx.set(projectRef.collection("members").doc(requesterId), {
        userId: requesterId,
        role: "member",
        joinedAt: FieldValue.serverTimestamp(),
      });
    }
    return { requesterId, title: project.get("title") as string };
  });

  await sendNotification({
    userId: result.requesterId,
    type: approve ? "joinApproved" : "joinRejected",
    message: approve
      ? `You were added to "${result.title}".`
      : `Your request to join "${result.title}" was declined.`,
    relatedId: projectId,
  });

  return { status: approve ? "approved" : "rejected" };
});
