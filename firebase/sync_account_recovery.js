const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
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

function phoneKey(phone) {
  return String(phone || "").replace(/\D/g, "");
}

function normalizePhone(phone) {
  let value = String(phone || "").trim().replace(/[\s()-]/g, "");
  if (value.startsWith("00")) value = `+${value.slice(2)}`;
  if (value.startsWith("+")) return value;
  if (value.startsWith("962")) return `+${value}`;
  if (value.startsWith("0")) return `+962${value.slice(1)}`;
  return `+962${value}`;
}

async function listUsers(accessToken) {
  const docs = [];
  let pageToken = "";
  do {
    const url = new URL(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users`);
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const response = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
    if (!response.ok) throw new Error(`List users failed: ${response.status} ${await response.text()}`);
    const body = await response.json();
    docs.push(...(body.documents || []));
    pageToken = body.nextPageToken || "";
  } while (pageToken);
  return docs;
}

async function commit(accessToken, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  for (let index = 0; index < writes.length; index += batchSize) {
    const chunk = writes.slice(index, index + batchSize);
    const response = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ writes: chunk }),
    });
    if (!response.ok) throw new Error(`Commit failed: ${response.status} ${await response.text()}`);
    console.log(`Synced ${Math.min(index + chunk.length, writes.length)}/${writes.length}`);
  }
}

async function main() {
  const accessToken = await getCliAccessToken();
  const users = await listUsers(accessToken);
  const writes = [];
  const seen = new Set();

  for (const doc of users) {
    const fields = doc.fields || {};
    const phone = normalizePhone(fields.phone?.stringValue);
    const email = fields.email?.stringValue;
    const key = phoneKey(phone);
    if (!phone || !email || !key || seen.has(key)) continue;
    seen.add(key);

    const uid = fields.uid?.stringValue || doc.name.split("/").pop();
    const data = {
      phone,
      email: email.toLowerCase(),
      uid,
      gymId: fields.gymId?.stringValue || "",
      role: fields.role?.stringValue || "",
      updatedAt: new Date().toISOString(),
    };
    writes.push({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/accountRecovery/${key}`,
        fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, firestoreValue(v)])),
      },
    });
  }

  console.log(`Recovery docs to sync: ${writes.length}`);
  if (writes.length) await commit(accessToken, writes);
  console.log("Done.");
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
