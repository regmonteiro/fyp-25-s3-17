// functions/src/index.ts
import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import dialogflow = require("@google-cloud/dialogflow");

if (admin.apps.length === 0) admin.initializeApp();

export const dialogflowGateway = onCall({ region: "asia-southeast1" }, async (request) => {
  const { userId, message, languageCode = "en" } = (request.data as any) ?? {};
  if (!message || typeof message !== "string") return { reply: "Empty message." };

  const projectId = process.env.GOOGLE_CLOUD_PROJECT!;
  const sessionId = (userId?.toString() || "anonymous").replace(/[^a-zA-Z0-9_-]/g, "_");

  const client = new dialogflow.SessionsClient();
  const sessionPath = client.projectAgentSessionPath(projectId, sessionId);

  const [resp] = await client.detectIntent({
    session: sessionPath,
    queryInput: { text: { text: message, languageCode } },
  });

  const qr: any = resp.queryResult || {};
  const reply =
    qr.fulfillmentText ||
    (qr.fulfillmentMessages?.map((m: any) => m.text?.text?.[0]).find(Boolean)) ||
    "Sorry, I didn't understand.";

  return { reply };
});
