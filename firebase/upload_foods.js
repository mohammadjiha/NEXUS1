const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const startIndex = Number(process.argv[3] || 0);
const foodsPath = path.resolve(__dirname, "..", "20k_gym_foods.json");
const collection = "foods";
const batchSize = Number(process.argv[4] || 200);

function requireFirebaseTools(modulePath) {
  const npmRoot =
    process.platform === "win32"
      ? execFileSync("cmd.exe", ["/c", "npm", "root", "-g"], {
          encoding: "utf8",
        }).trim()
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
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreValue) } };
  }
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: value }
      : { doubleValue: value };
  }
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, nestedValue]) => [
            key,
            firestoreValue(nestedValue),
          ])
        ),
      },
    };
  }
  throw new Error(`Unsupported Firestore value: ${value}`);
}

function slugPart(value) {
  return String(value || "food")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80) || "food";
}

function searchPrefixes(name) {
  const normalized = name.toLowerCase().replace(/[^a-z0-9\s]+/g, " ").trim();
  const words = normalized.split(/\s+/).filter(Boolean).slice(0, 6);
  const prefixes = new Set();
  for (const word of words) {
    const max = Math.min(word.length, 12);
    for (let i = 1; i <= max; i += 1) prefixes.add(word.slice(0, i));
  }
  return [...prefixes].slice(0, 60);
}

function normalizeFood(food, index) {
  const name = String(food.name || "").trim();
  const tags = Array.isArray(food.tags) ? food.tags.map(String) : [];
  return {
    externalId: String(food.id || ""),
    importIndex: index,
    name,
    nameLower: name.toLowerCase(),
    namePrefixes: searchPrefixes(name),
    emoji: String(food.emoji || "🍽️"),
    servingSize: String(food.servingSize || ""),
    calories: Number(food.calories) || 0,
    protein: Number(food.protein) || 0,
    carbs: Number(food.carbs) || 0,
    fat: Number(food.fat) || 0,
    gymScore: Number(food.gymScore) || 0,
    tags,
    tagText: tags.join(" ").toLowerCase(),
    source: "20k_gym_foods.json",
  };
}

function documentName(docId) {
  return `projects/${projectId}/databases/(default)/documents/${collection}/${docId}`;
}

async function commitBatch(accessToken, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes }),
    });
    if (response.ok) return;

    const body = await response.text();
    if (response.status !== 429 && response.status < 500) {
      throw new Error(`Commit failed: ${response.status} ${body}`);
    }

    const delayMs = Math.min(120000, 5000 * 2 ** attempt);
    console.log(
      `Commit hit ${response.status}; retrying in ${Math.round(delayMs / 1000)}s...`
    );
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }
  throw new Error("Commit failed after retries.");
}

async function countFoods(accessToken) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runAggregationQuery`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredAggregationQuery: {
        structuredQuery: {
          from: [{ collectionId: collection }],
        },
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
  if (!Array.isArray(foods)) throw new Error("Foods JSON must be an array.");

  const accessToken = await getCliAccessToken();
  const importedAt = new Date().toISOString();
  let writes = [];
  let uploaded = startIndex;

  for (let i = startIndex; i < foods.length; i += 1) {
    const normalized = {
      ...normalizeFood(foods[i], i),
      importedAt,
    };
    const docId = `${slugPart(normalized.externalId)}-${String(i).padStart(5, "0")}`;
    writes.push({
      update: {
        name: documentName(docId),
        fields: Object.fromEntries(
          Object.entries(normalized).map(([key, value]) => [key, firestoreValue(value)])
        ),
      },
    });

    if (writes.length === batchSize) {
      await commitBatch(accessToken, writes);
      uploaded += writes.length;
      writes = [];
      console.log(`Uploaded ${uploaded}/${foods.length}`);
    }
  }

  if (writes.length > 0) {
    await commitBatch(accessToken, writes);
    uploaded += writes.length;
    console.log(`Uploaded ${uploaded}/${foods.length}`);
  }

  const total = await countFoods(accessToken);
  console.log(`Done. Uploaded ${uploaded} documents to ${collection}. Firestore count: ${total ?? "unknown"}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
