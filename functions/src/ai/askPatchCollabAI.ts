import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { GoogleGenAI } from "@google/genai";
import { db } from "../admin";

// Set with: firebase functions:secrets:set GEMINI_API_KEY (needs Blaze).
// For the emulator, put GEMINI_API_KEY=... in functions/.secret.local (gitignored).
const geminiKey = defineSecret("GEMINI_API_KEY");

// Check AI Studio for the current Flash model name before deploying,
const MODEL = "gemini-flash-latest";

// The free tier is shared across the whole project, so each student gets a small share.
const DAILY_CAP = 20;
const MAX_PROMPT_CHARS = 4000;

const REQUEST_TYPES = ["review", "summarise", "explain"] as const;
type RequestType = (typeof REQUEST_TYPES)[number];

const BASE = "You are PatchCollab AI, an assistant for undergraduate software engineering students.";
const INSTRUCTIONS: Record<RequestType, string> = {
  review: `${BASE} Review the code the student submits. Point out bugs, unclear naming and structural problems, and explain each one briefly.`,
  summarise: `${BASE} Summarise what the submitted code or text does in plain language.`,
  explain: `${BASE} Explain the submitted code or concept step by step at an undergraduate level.`,
};

// Start of the current day in South Africa, as a UTC Date
function startOfTodaySast(): Date {
  const offsetMs = 2 * 60 * 60 * 1000;
  const shifted = new Date(Date.now() + offsetMs);
  return new Date(
    Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()) - offsetMs
  );
}

export const askPatchCollabAI = onCall(
  { region: "africa-south1", secrets: [geminiKey] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to use PatchCollab AI.");
    }

    const { prompt, type } = request.data ?? {};
    if (typeof prompt !== "string" || prompt.trim().length === 0 || prompt.length > MAX_PROMPT_CHARS) {
      throw new HttpsError("invalid-argument", `Prompt must be 1 to ${MAX_PROMPT_CHARS} characters.`);
    }
    if (typeof type !== "string" || !REQUEST_TYPES.includes(type as RequestType)) {
      throw new HttpsError("invalid-argument", "Type must be review, summarise or explain.");
    }

    const requests = db.collection("aiRequests");
    const newRef = requests.doc();
    let usedBefore = 0;

    // Count today's requests and reserve a slot in the same transaction
    await db.runTransaction(async (tx) => {
      const countSnap = await tx.get(
        requests
          .where("userId", "==", uid)
          .where("createdAt", ">=", Timestamp.fromDate(startOfTodaySast()))
          .count()
      );
      usedBefore = countSnap.data().count;
      if (usedBefore >= DAILY_CAP) {
        throw new HttpsError("resource-exhausted", "You have reached today's PatchCollab AI limit.");
      }
      tx.create(newRef, {
        requestId: newRef.id,
        userId: uid,
        prompt,
        response: null,
        createdAt: FieldValue.serverTimestamp(),
        type,
      });
    });

    try {
      const ai = new GoogleGenAI({ apiKey: geminiKey.value() });
      const result = await ai.models.generateContent({
        model: MODEL,
        contents: prompt,
        config: { systemInstruction: INSTRUCTIONS[type as RequestType] },
      });
      const text = result.text ?? "";
      await newRef.update({ response: text });
      return { requestId: newRef.id, response: text, remaining: DAILY_CAP - usedBefore - 1 };
    } catch (err) {
      // Give the slot back if Gemini failed
      logger.error("Gemini call failed", err);
      await newRef.delete();
      throw new HttpsError("internal", "PatchCollab AI is unavailable right now.");
    }
  }
);
