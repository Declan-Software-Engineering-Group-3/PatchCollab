// Callable: the question's author marks one answer as accepted, or clears it
// by passing answerId: null. acceptedAnswerId and isAccepted are Cloud Function only.
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../admin";
import { REGION } from "../config";

export const acceptAnswer = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const { questionId, answerId } = request.data ?? {};
  if (typeof questionId !== "string" || questionId.length === 0) {
    throw new HttpsError("invalid-argument", "questionId is required.");
  }
  if (answerId !== null && (typeof answerId !== "string" || answerId.length === 0)) {
    throw new HttpsError("invalid-argument", "answerId must be a string or null.");
  }

  const questionRef = db.collection("questions").doc(questionId);

  await db.runTransaction(async (tx) => {
    const question = await tx.get(questionRef);
    if (!question.exists) throw new HttpsError("not-found", "Question not found.");
    if (question.get("userId") !== uid) {
      throw new HttpsError("permission-denied", "Only the question's author can accept an answer.");
    }

    const previousId: string | null = question.get("acceptedAnswerId") ?? null;
    if (previousId === answerId) return;

    // Reads must all happen before writes in a transaction
    let newAnswerRef = null;
    if (answerId !== null) {
      newAnswerRef = db.collection("answers").doc(answerId);
      const answer = await tx.get(newAnswerRef);
      if (!answer.exists || answer.get("questionId") !== questionId) {
        throw new HttpsError("not-found", "That answer does not belong to this question.");
      }
    }
    let previousRef = null;
    if (previousId !== null) {
      previousRef = db.collection("answers").doc(previousId);
      const previous = await tx.get(previousRef);
      if (!previous.exists) previousRef = null;
    }

    if (previousRef) tx.update(previousRef, { isAccepted: false });
    if (newAnswerRef) tx.update(newAnswerRef, { isAccepted: true });
    tx.update(questionRef, { acceptedAnswerId: answerId });
  });

  return { questionId, acceptedAnswerId: answerId };
});
