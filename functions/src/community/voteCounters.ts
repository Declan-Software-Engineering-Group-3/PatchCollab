// Keeps voteCount on questions and answers in step with their votes subcollections.
// One vote document per voter (doc id = voter uid), value 1 or -1. Clients can
// create, change or delete their vote; this applies the difference.
import { onDocumentWritten, FirestoreEvent, Change, DocumentSnapshot } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { db } from "../admin";
import { REGION } from "../config";

function voteValue(snap: DocumentSnapshot | undefined): number {
  if (!snap || !snap.exists) return 0;
  const v = snap.get("value");
  return v === 1 || v === -1 ? v : 0;
}

async function applyDelta(
  collection: "questions" | "answers",
  parentId: string,
  event: FirestoreEvent<Change<DocumentSnapshot> | undefined>
): Promise<void> {
  const delta = voteValue(event.data?.after) - voteValue(event.data?.before);
  if (delta === 0) return;
  try {
    await db.collection(collection).doc(parentId).update({ voteCount: FieldValue.increment(delta) });
  } catch (err) {
    // The parent was deleted. Nothing to count.
    logger.warn(`Could not update ${collection}/${parentId} voteCount`, err);
  }
}

export const onQuestionVoteWritten = onDocumentWritten(
  { document: "questions/{questionId}/votes/{voterId}", region: REGION },
  (event) => applyDelta("questions", event.params.questionId, event)
);

export const onAnswerVoteWritten = onDocumentWritten(
  { document: "answers/{answerId}/votes/{voterId}", region: REGION },
  (event) => applyDelta("answers", event.params.answerId, event)
);
