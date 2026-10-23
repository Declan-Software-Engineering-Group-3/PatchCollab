import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../admin";
import { createAndSendNotification } from "../social/notifications";

// Only the author of the question can accept an answer. The client cannot
// write isAccepted or acceptedAnswerId (see firestore.rules), so it comes here.
export const acceptAnswer = onCall({ region: "africa-south1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to accept an answer.");
  }

  const { questionId, answerId } = request.data ?? {};
  if (typeof questionId !== "string" || typeof answerId !== "string" || !questionId || !answerId) {
    throw new HttpsError("invalid-argument", "questionId and answerId are required.");
  }

  const questionRef = db.collection("questions").doc(questionId);
  const answerRef = db.collection("answers").doc(answerId);

  let answerAuthorId = "";
  let questionTitle = "";

  await db.runTransaction(async (tx) => {
    const [questionSnap, answerSnap] = await Promise.all([tx.get(questionRef), tx.get(answerRef)]);

    if (!questionSnap.exists) {
      throw new HttpsError("not-found", "Question not found.");
    }
    if (!answerSnap.exists || answerSnap.data()?.questionId !== questionId) {
      throw new HttpsError("not-found", "Answer not found on this question.");
    }
    if (questionSnap.data()?.userId !== uid) {
      throw new HttpsError("permission-denied", "Only the question author can accept an answer.");
    }

    answerAuthorId = answerSnap.data()?.userId as string;
    questionTitle = (questionSnap.data()?.title ?? "") as string;

    const previousId = questionSnap.data()?.acceptedAnswerId as string | null | undefined;
    if (previousId === answerId) return;

    // Switching to a different answer un-accepts the old one
    if (previousId) {
      tx.update(db.collection("answers").doc(previousId), { isAccepted: false });
    }
    tx.update(answerRef, { isAccepted: true });
    tx.update(questionRef, { acceptedAnswerId: answerId });
  });

  if (answerAuthorId && answerAuthorId !== uid) {
    await createAndSendNotification({
      userId: answerAuthorId,
      type: "answerAccepted",
      message: `Your answer to "${questionTitle}" was accepted.`,
      relatedId: questionId,
    });
  }

  return { questionId, answerId };
});
