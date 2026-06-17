const { execFileSync } = require("child_process");
const path = require("path");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "foods";
const deleteBatchSize = Number(process.argv[3] || 300);

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

function parseValue(value) {
  if (!value) return undefined;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("arrayValue" in value) return value.arrayValue.values?.map(parseValue) ?? [];
  if ("nullValue" in value) return null;
  return undefined;
}

function field(fields, name) {
  return parseValue(fields?.[name]);
}

function normText(value) {
  return String(value ?? "").trim().toLowerCase().replace(/\s+/g, " ");
}

function normNum(value) {
  return Number(Number(value || 0).toFixed(2));
}

function duplicateKey(fields) {
  return [
    normText(field(fields, "name")),
    normText(field(fields, "servingSize")),
    normNum(field(fields, "calories")),
    normNum(field(fields, "protein")),
    normNum(field(fields, "carbs")),
    normNum(field(fields, "fat")),
  ].join("|");
}

function importIndex(fields) {
  const index = field(fields, "importIndex");
  return Number.isFinite(index) ? index : Number.MAX_SAFE_INTEGER;
}

async function runQuery(accessToken, pageToken) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: collection }],
      orderBy: [{ field: { fieldPath: "__name__" }, direction: "ASCENDING" }],
      limit: 1000,
      ...(pageToken
        ? {
            startAt: {
              values: [{ referenceValue: pageToken }],
              before: false,
            },
          }
        : {}),
    },
  };
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Query failed: ${response.status} ${text}`);
  }
  return response.json();
}

async function commitDeletes(accessToken, documentNames) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  for (let i = 0; i < documentNames.length; i += deleteBatchSize) {
    const chunk = documentNames.slice(i, i + deleteBatchSize);
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes: chunk.map((name) => ({ delete: name })) }),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Delete failed: ${response.status} ${text}`);
    }
    console.log(`Deleted ${Math.min(i + chunk.length, documentNames.length)}/${documentNames.length}`);
  }
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
        structuredQuery: { from: [{ collectionId: collection }] },
        aggregations: [{ alias: "total", count: {} }],
      },
    }),
  });
  if (!response.ok) return null;
  const rows = await response.json();
  return Number(rows?.[0]?.result?.aggregateFields?.total?.integerValue ?? 0);
}

async function main() {
  const accessToken = await getCliAccessToken();
  const keepByKey = new Map();
  const duplicates = [];
  let scanned = 0;
  let startAfter = null;

  while (true) {
    const rows = await runQuery(accessToken, startAfter);
    const docs = rows.map((row) => row.document).filter(Boolean);
    if (docs.length === 0) break;

    for (const doc of docs) {
      scanned += 1;
      const key = duplicateKey(doc.fields);
      const current = { name: doc.name, index: importIndex(doc.fields) };
      const kept = keepByKey.get(key);
      if (!kept) {
        keepByKey.set(key, current);
      } else if (current.index < kept.index) {
        duplicates.push(kept.name);
        keepByKey.set(key, current);
      } else {
        duplicates.push(current.name);
      }
    }

    startAfter = docs[docs.length - 1].name;
    console.log(`Scanned ${scanned}`);
    if (docs.length < 1000) break;
  }

  console.log(`Scanned ${scanned}. Unique ${keepByKey.size}. Duplicates to delete ${duplicates.length}.`);
  if (duplicates.length > 0) await commitDeletes(accessToken, duplicates);
  const total = await countFoods(accessToken);
  console.log(`Done. Firestore count: ${total ?? "unknown"}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
