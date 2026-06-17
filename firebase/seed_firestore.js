const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const seedPath = path.join(__dirname, "firestore.seed.json");
const seed = JSON.parse(fs.readFileSync(seedPath, "utf8"));

function requireFirebaseTools(modulePath) {
  const npmRoot =
    process.platform === "win32"
      ? execFileSync("cmd.exe", ["/c", "npm", "root", "-g"], { encoding: "utf8" }).trim()
      : execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
  return require(path.join(npmRoot, "firebase-tools", "lib", modulePath));
}

async function getCliAccessToken() {
  const auth = requireFirebaseTools("auth.js");
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI is not logged in. Run `firebase login` first.");
  }

  const token = await auth.getAccessToken(account.tokens.refresh_token, [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/firebase",
  ]);

  if (!token?.access_token) {
    throw new Error("Could not get an access token from Firebase CLI credentials.");
  }

  return token.access_token;
}

function firestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreValue) } };
  }
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value) ? { integerValue: value } : { doubleValue: value };
  }
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, nestedValue]) => [key, firestoreValue(nestedValue)])
        ),
      },
    };
  }
  throw new Error(`Unsupported Firestore value: ${value}`);
}

function documentBody(data) {
  const now = new Date().toISOString();
  const withAudit = {
    ...data,
    updatedAt: now,
    createdAt: data.createdAt || now,
  };

  return {
    fields: Object.fromEntries(
      Object.entries(withAudit).map(([key, value]) => [key, firestoreValue(value)])
    ),
  };
}

async function upsertDocument(accessToken, collection, id, data) {
  const collectionPath = collection
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/${collectionPath}/${encodeURIComponent(id)}`;

  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(documentBody(data)),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Failed to seed ${collection}/${id}: ${response.status} ${body}`);
  }
}

async function main() {
  const accessToken = await getCliAccessToken();
  let count = 0;

  for (const [collection, documents] of Object.entries(seed)) {
    for (const [id, data] of Object.entries(documents)) {
      await upsertDocument(accessToken, collection, id, data);
      count += 1;
      console.log(`Seeded ${collection}/${id}`);
    }
  }

  console.log(`Done. Seeded ${count} Firestore documents in ${projectId}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
