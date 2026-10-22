import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../admin";
import { createAndSendNotification } from "../social/notifications";

// Tell the question author when someone answers
export const onAnswerCreated = onDocumentCreated(
  { document: "answers/{answerId}", region: "africa-south1" },
  async (event) => {
    const answer = event.data?.data();
    if (!answer) return;

    const questionSnap = await db.collection("questions").doc(answer.questionId as string).get();
    if (!questionSnap.exists) return;

    const question = questionSnap.data()!;
    const answererId = answer.userId as string;
    if (question.userId === answererId) return;

    const answererSnap = await db.collection("users").doc(answererId).get();
    const name = (answererSnap.data()?.displayName ?? "Someone") as string;

    await createAndSendNotification({
      userId: question.userId as string,
      type: "newAnswer",
      message: `${name} answered your question: ${question.title}`,
      relatedId: questionSnap.id,
    });
  }
);
