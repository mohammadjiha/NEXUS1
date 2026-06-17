const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const foodsPath = path.resolve(__dirname, "..", "20k_gym_foods_ar_deduped.json");
const collection = "foods";
const batchSize = Number(process.argv[3] || 200);

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

async function listFoodDocIds(accessToken) {
  const ids = [];
  let pageToken = "";
  do {
    const url = new URL(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}`);
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) {
      throw new Error(`List failed: ${response.status} ${await response.text()}`);
    }
    const body = await response.json();
    for (const doc of body.documents || []) {
      ids.push(doc.name.split("/").pop());
    }
    pageToken = body.nextPageToken || "";
  } while (pageToken);
  return ids;
}

async function commitDeletes(accessToken, docIds) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  for (let index = 0; index < docIds.length; index += batchSize) {
    const chunk = docIds.slice(index, index + batchSize);
    const writes = chunk.map((docId) => ({
      delete: `projects/${projectId}/databases/(default)/documents/${collection}/${docId}`,
    }));
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes }),
    });
    if (!response.ok) {
      throw new Error(`Delete failed: ${response.status} ${await response.text()}`);
    }
    console.log(`Deleted ${Math.min(index + chunk.length, docIds.length)}/${docIds.length}`);
  }
}

async function countFoods(accessToken) {
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
  const foods = JSON.parse(fs.readFileSync(foodsPath, "utf8"));
  const validDocIds = new Set(foods.map((food) => String(food.docId || "").trim()).filter(Boolean));
  const accessToken = await getCliAccessToken();
  const existingDocIds = await listFoodDocIds(accessToken);
  const extras = existingDocIds.filter((docId) => !validDocIds.has(docId));
  console.log(`Existing docs: ${existingDocIds.length}`);
  console.log(`Valid docs: ${validDocIds.size}`);
  console.log(`Extra docs to delete: ${extras.length}`);
  if (extras.length > 0) {
    await commitDeletes(accessToken, extras);
  }
  const total = await countFoods(accessToken);
  console.log(`Done. Firestore count: ${total ?? "unknown"}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
