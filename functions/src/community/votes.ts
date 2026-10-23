import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { AggregateField } from "firebase-admin/firestore";
import { db } from "../admin";

// voteCount is the sum of the vote documents (1 or -1). Recounting on every
// write instead of adding a delta means a retried or duplicated event can't
// make the count drift.
async function recount(collection: "questions" | "answers", docId: string): Promise<void> {
  const parentRef = db.collection(collection).doc(docId);
  const parentSnap = await parentRef.get();
  if (!parentSnap.exists) return;

  const result = await parentRef
    .collection("votes")
    .aggregate({ total: AggregateField.sum("value") })
    .get();

  await parentRef.update({ voteCount: result.data().total ?? 0 });
}

export const onQuestionVoteWritten = onDocumentWritten(
  { document: "questions/{questionId}/votes/{voterId}", region: "africa-south1" },
  async (event) => recount("questions", event.params.questionId)
);

export const onAnswerVoteWritten = onDocumentWritten(
  { document: "answers/{answerId}/votes/{voterId}", region: "africa-south1" },
  async (event) => recount("answers", event.params.answerId)
);
