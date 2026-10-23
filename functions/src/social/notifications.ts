// Notifications for friend requests and new messages.
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../admin";
import { REGION } from "../config";
import { sendNotification } from "../notify";

async function displayName(uid: string): Promise<string> {
  const user = await db.collection("users").doc(uid).get();
  return (user.get("displayName") as string | undefined) ?? "Someone";
}

export const onFriendshipCreated = onDocumentCreated(
  { document: "friendships/{friendshipId}", region: REGION },
  async (event) => {
    const f = event.data;
    if (!f || f.get("status") !== "pending") return;
    const name = await displayName(f.get("userId"));
    await sendNotification({
      userId: f.get("friendId"),
      type: "friendRequest",
      message: `${name} sent you a friend request.`,
      relatedId: event.params.friendshipId,
    });
  }
);

export const onMessageCreated = onDocumentCreated(
  { document: "conversations/{conversationId}/messages/{messageId}", region: REGION },
  async (event) => {
    const msg = event.data;
    if (!msg) return;
    const convo = await db.collection("conversations").doc(event.params.conversationId).get();
    if (!convo.exists) return;

    const senderId: string = msg.get("senderId");
    const participants: string[] = convo.get("participants") ?? [];
    const recipientId = participants.find((p) => p !== senderId);
    if (!recipientId) return;

    const name = await displayName(senderId);
    const text: string = msg.get("text") ?? "";
    await sendNotification({
      userId: recipientId,
      type: "newMessage",
      message: `${name}: ${text.length > 80 ? text.slice(0, 77) + "..." : text}`,
      relatedId: event.params.conversationId,
    });
  }
);
