// Shared notification helper. SCHEMA.md says notifications are only ever created
// by Cloud Functions, so every feature folder calls this instead of writing directly.
import { FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import { db } from "./admin";

export type NotificationType =
  | "newAnswer"
  | "newReviewRequest"
  | "friendRequest"
  | "joinRequest"
  | "joinApproved"
  | "joinRejected"
  | "newMessage";

export interface NotificationInput {
  userId: string; // recipient
  type: NotificationType;
  message: string;
  relatedId?: string | null;
}

// FCM error codes that mean the token will never work again
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

export async function sendNotification(input: NotificationInput): Promise<void> {
  const ref = db.collection("notifications").doc();
  await ref.set({
    notificationId: ref.id,
    userId: input.userId,
    type: input.type,
    message: input.message,
    relatedId: input.relatedId ?? null,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Push is best effort. The Firestore document above is the source of truth.
  const userSnap = await db.collection("users").doc(input.userId).get();
  const tokens: string[] = userSnap.get("fcmTokens") ?? [];
  if (tokens.length === 0) return;

  try {
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: "PatchCollab", body: input.message },
      data: {
        notificationId: ref.id,
        type: input.type,
        relatedId: input.relatedId ?? "",
      },
    });
    const dead = tokens.filter((_, i) => {
      const code = res.responses[i].error?.code;
      return code !== undefined && DEAD_TOKEN_CODES.has(code);
    });
    if (dead.length > 0) {
      await userSnap.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
    }
  } catch (err) {
    logger.error("FCM send failed", { userId: input.userId, err });
  }
}
