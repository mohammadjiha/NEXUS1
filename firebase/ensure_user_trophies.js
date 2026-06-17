const path = require("path");
const { execFileSync } = require("child_process");

const projectId = process.argv[2] || "nexus-90e55";
const collection = "users";
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

async function listUsers(accessToken) {
  const docs = [];
  let pageToken = "";
  do {
    const url = new URL(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}`);
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) throw new Error(`List failed: ${response.status} ${await response.text()}`);
    const body = await response.json();
    docs.push(...(body.documents || []));
    pageToken = body.nextPageToken || "";
  } while (pageToken);
  return docs;
}

function integerField(value) {
  return { integerValue: String(value) };
}

async function commitUpdates(accessToken, writes) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  for (let index = 0; index < writes.length; index += batchSize) {
    const chunk = writes.slice(index, index + batchSize);
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes: chunk }),
    });
    if (!response.ok) throw new Error(`Commit failed: ${response.status} ${await response.text()}`);
    console.log(`Updated ${Math.min(index + chunk.length, writes.length)}/${writes.length}`);
  }
}

async function main() {
  const accessToken = await getCliAccessToken();
  const docs = await listUsers(accessToken);
  const writes = [];

  for (const doc of docs) {
    const fields = doc.fields || {};
    const role = fields.role?.stringValue || "";
    if (role.toLowerCase() !== "player") continue;
    const needsTrophies = fields.trophies == null;
    const needsCups = fields.cups == null;
    if (!needsTrophies && !needsCups) continue;

    const updateFields = {};
    const updateMask = [];
    if (needsTrophies) {
      updateFields.trophies = integerField(0);
      updateMask.push("trophies");
    }
    if (needsCups) {
      updateFields.cups = integerField(0);
      updateMask.push("cups");
    }

    writes.push({
      update: {
        name: doc.name,
        fields: updateFields,
      },
      updateMask: {
        fieldPaths: updateMask,
      },
    });
  }

  console.log(`Players needing trophy defaults: ${writes.length}`);
  if (writes.length > 0) await commitUpdates(accessToken, writes);
  console.log("Done.");
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
