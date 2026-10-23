import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../admin";
import { createAndSendNotification } from "../social/notifications";

// Tell the project owner when someone asks to join
export const onJoinRequestCreated = onDocumentCreated(
  { document: "projects/{projectId}/membershipRequests/{requestId}", region: "africa-south1" },
  async (event) => {
    const joinRequest = event.data?.data();
    if (!joinRequest || joinRequest.status !== "pending") return;

    const projectSnap = await db.collection("projects").doc(event.params.projectId).get();
    if (!projectSnap.exists) return;

    const project = projectSnap.data()!;
    const requesterId = joinRequest.userId as string;
    if (project.ownerId === requesterId) return;

    const requesterSnap = await db.collection("users").doc(requesterId).get();
    const name = (requesterSnap.data()?.displayName ?? "Someone") as string;

    await createAndSendNotification({
      userId: project.ownerId as string,
      type: "joinRequest",
      message: `${name} asked to join ${project.title}`,
      relatedId: projectSnap.id,
    });
  }
);
