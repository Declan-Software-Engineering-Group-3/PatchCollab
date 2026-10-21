import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {db} from "../admin";

type NotificationType =
  | "friendRequest"
  | "friendAccepted"
  | "newMessage";

interface NotificationPayload {
  userId: string;
  type: NotificationType;
  message: string;
  relatedId?: string;
}

export async function createAndSendNotification(
  payload: NotificationPayload,
): Promise<void> {
  const notificationRef = db.collection("notifications").doc();

  await notificationRef.set({
    notificationId: notificationRef.id,
    userId: payload.userId,
    type: payload.type,
    message: payload.message,
    relatedId: payload.relatedId ?? null,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const userSnap = await db.collection("users").doc(payload.userId).get();
  const tokens = (userSnap.data()?.fcmTokens ?? []) as string[];

  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: "PatchCollab",
      body: payload.message,
    },
    data: {
      type: payload.type,
      relatedId: payload.relatedId ?? "",
    },
  });

  const staleTokens: string[] = [];

  response.responses.forEach((result, index) => {
    if (!result.success) {
      const code = result.error?.code;

      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        staleTokens.push(tokens[index]);
      }
    }
  });

  if (staleTokens.length > 0) {
    await db.collection("users").doc(payload.userId).update({
      fcmTokens: FieldValue.arrayRemove(...staleTokens),
    });
  }
}

export const onFriendRequestCreated = onDocumentCreated(
  {
    document: "friendships/{friendshipId}",
    region: "africa-south1",
  },
  async (event) => {
    const data = event.data?.data();

    if (!data || data.status !== "pending") return;

    const senderId = data.userId as string;
    const recipientId = data.friendId as string;

    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName =
      (senderSnap.data()?.displayName ?? "Someone") as string;

    await createAndSendNotification({
      userId: recipientId,
      type: "friendRequest",
      message: `${senderName} sent you a friend request.`,
      relatedId: event.params.friendshipId,
    });
  },
);

export const onFriendshipUpdated = onDocumentUpdated(
  {
    document: "friendships/{friendshipId}",
    region: "africa-south1",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    if (
      before.status === after.status ||
      after.status !== "accepted"
    ) {
      return;
    }

    const requesterId = after.userId as string;
    const accepterId = after.friendId as string;

    const accepterSnap =
      await db.collection("users").doc(accepterId).get();

    const accepterName =
      (accepterSnap.data()?.displayName ?? "Someone") as string;

    await createAndSendNotification({
      userId: requesterId,
      type: "friendAccepted",
      message: `${accepterName} accepted your friend request.`,
      relatedId: event.params.friendshipId,
    });
  },
);

export const onMessageCreated = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    region: "africa-south1",
  },
  async (event) => {
    const message = event.data?.data();

    if (!message) return;

    const conversationId = event.params.conversationId;
    const senderId = message.senderId as string;
    const text = message.text as string;

    const conversationSnap = await db
      .collection("conversations")
      .doc(conversationId)
      .get();

    const participants =
      (conversationSnap.data()?.participants ?? []) as string[];

    const recipientId =
      participants.find((id) => id !== senderId);

    if (!recipientId) return;

    const senderSnap =
      await db.collection("users").doc(senderId).get();

    const senderName =
      (senderSnap.data()?.displayName ?? "Someone") as string;

    const preview =
      text.length > 80
        ? `${text.substring(0, 77)}...`
        : text;

    await createAndSendNotification({
      userId: recipientId,
      type: "newMessage",
      message: `${senderName}: ${preview}`,
      relatedId: conversationId,
    });
  },
);