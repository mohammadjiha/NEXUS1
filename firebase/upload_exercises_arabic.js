const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const startIndex = Number(process.argv[3] || 0);
const batchSize = Number(process.argv[4] || 200);
const exercisesPath = path.resolve(__dirname, "..", "exercises_ar_firestore.json");
const collection = "exercises";

function requireFirebaseTools(modulePath) {
  const npmRoot =
    process.platform === "win32"
      ? execFileSync("cmd.exe", ["/c", "npm", "root", "-g"], { encoding: "utf8" }).trim()
      : execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
  return require(path.join(npmRoot, "firebase-tools", "lib", modulePath));
}

async function getCliAccessToken() {
  const auth = requireFirebaseTools("auth.js");
  const { requireAuth } = requireFirebaseTools("requireAuth.js");
  const apiv2 = requireFirebaseTools("apiv2.js");
  const account = auth.getGlobalDefaultAccount();
  if (!account?.user || !account?.tokens) {
    throw new Error("Firebase CLI is not logged in. Run `firebase login` first.");
  }
  await requireAuth({ user: account.user, tokens: account.tokens, project: projectId });
  return apiv2.getAccessToken();
}

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(firestoreValue) } };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") return Number.isInteger(value) ? { integerValue: value } : { doubleValue: value };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(Object.entries(value).map(([key, nestedValue]) => [key, firestoreValue(nestedValue)])),
      },
    };
  }
  throw new Error(`Unsupported Firestore value: ${value}`);
}

async function commitBatch(accessToken, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const response = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ writes }),
  });
  if (!response.ok) throw new Error(`Commit failed: ${response.status} ${await response.text()}`);
}

async function countExercises(accessToken) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runAggregationQuery`;
  const response = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      structuredAggregationQuery: {
        structuredQuery: { from: [{ collectionId: collection }] },
        aggregations: [{ alias: "total", count: {} }],
      },
    }),
  });
  if (!response.ok) return null;
  const rows = await response.json();
  const value = rows?.[0]?.result?.aggregateFields?.total?.integerValue;
  return value == null ? null : Number(value);
}

async function main() {
  const exercises = JSON.parse(fs.readFileSync(exercisesPath, "utf8"));
  const accessToken = await getCliAccessToken();
  let writes = [];
  let uploaded = startIndex;
  for (let i = startIndex; i < exercises.length; i += 1) {
    const exercise = { ...exercises[i], arabicUpdatedAt: new Date().toISOString() };
    const docId = exercise.id;
    writes.push({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/${collection}/${docId}`,
        fields: Object.fromEntries(Object.entries(exercise).map(([key, value]) => [key, firestoreValue(value)])),
      },
    });
    if (writes.length === batchSize) {
      await commitBatch(accessToken, writes);
      uploaded += writes.length;
      writes = [];
      console.log(`Uploaded ${uploaded}/${exercises.length}`);
    }
  }
  if (writes.length > 0) {
    await commitBatch(accessToken, writes);
    uploaded += writes.length;
    console.log(`Uploaded ${uploaded}/${exercises.length}`);
  }
  const total = await countExercises(accessToken);
  console.log(`Done. Uploaded ${uploaded} exercises. Firestore count: ${total ?? "unknown"}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
