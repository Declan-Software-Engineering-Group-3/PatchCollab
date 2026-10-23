// Tells a question's author when someone answers it.
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../admin";
import { REGION } from "../config";
import { sendNotification } from "../notify";

export const onAnswerCreated = onDocumentCreated(
  { document: "answers/{answerId}", region: REGION },
  async (event) => {
    const answer = event.data;
    if (!answer) return;
    const questionId: string = answer.get("questionId");
    const question = await db.collection("questions").doc(questionId).get();
    if (!question.exists) return;

    const authorId: string = question.get("userId");
    if (authorId === answer.get("userId")) return; // answering your own question

    const kind = question.get("type") === "reviewRequest" ? "review request" : "question";
    await sendNotification({
      userId: authorId,
      type: "newAnswer",
      message: `Someone answered your ${kind} "${question.get("title")}".`,
      relatedId: questionId,
    });
  }
);
