import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../admin";
import { createAndSendNotification } from "../social/notifications";

// Only the author of the question can accept an answer. The client cannot
// write isAccepted or acceptedAnswerId (see firestore.rules), so it comes here.
// Passing answerId: null clears the accepted answer.
export const acceptAnswer = onCall({ region: "africa-south1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to accept an answer.");
  }

  const { questionId, answerId } = request.data ?? {};
  if (typeof questionId !== "string" || !questionId) {
    throw new HttpsError("invalid-argument", "questionId is required.");
  }
  if (answerId !== null && (typeof answerId !== "string" || !answerId)) {
    throw new HttpsError("invalid-argument", "answerId must be a string or null.");
  }

  const questionRef = db.collection("questions").doc(questionId);
  const answerRef = answerId === null ? null : db.collection("answers").doc(answerId);

  let answerAuthorId = "";
  let questionTitle = "";

  await db.runTransaction(async (tx) => {
    const [questionSnap, answerSnap] = await Promise.all([
      tx.get(questionRef),
      answerRef ? tx.get(answerRef) : Promise.resolve(null),
    ]);

    if (!questionSnap.exists) {
      throw new HttpsError("not-found", "Question not found.");
    }
    if (answerSnap && (!answerSnap.exists || answerSnap.data()?.questionId !== questionId)) {
      throw new HttpsError("not-found", "Answer not found on this question.");
    }
    if (questionSnap.data()?.userId !== uid) {
      throw new HttpsError("permission-denied", "Only the question author can accept an answer.");
    }

    answerAuthorId = (answerSnap?.data()?.userId ?? "") as string;
    questionTitle = (questionSnap.data()?.title ?? "") as string;

    const previousId = (questionSnap.data()?.acceptedAnswerId ?? null) as string | null;
    if (previousId === answerId) return;

    // Switching to a different answer, or clearing, un-accepts the old one
    if (previousId) {
      tx.update(db.collection("answers").doc(previousId), { isAccepted: false });
    }
    if (answerRef) tx.update(answerRef, { isAccepted: true });
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
