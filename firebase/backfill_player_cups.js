const { execFileSync } = require("child_process");
const path = require("path");

const projectId = "nexus-90e55";

function requireFirebaseTools(modulePath) {
  const npmRoot = execFileSync("cmd.exe", ["/c", "npm", "root", "-g"], {
    encoding: "utf8",
  }).trim();
  return require(path.join(npmRoot, "firebase-tools", "lib", modulePath));
}

async function getCliAccessToken() {
  const auth = requireFirebaseTools("auth.js");
  const { requireAuth } = requireFirebaseTools("requireAuth.js");
  const apiv2 = requireFirebaseTools("apiv2.js");
  const account = auth.getGlobalDefaultAccount();
  if (!account?.user || !account?.tokens) {
    throw new Error("Firebase CLI is not logged in.");
  }
  await requireAuth({
    user: account.user,
    tokens: account.tokens,
    project: projectId,
  });
  return apiv2.getAccessToken();
}

function parseValue(value) {
  if (!value) return undefined;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("nullValue" in value) return null;
  if ("arrayValue" in value) return value.arrayValue.values?.map(parseValue) ?? [];
  return undefined;
}

function parseDoc(doc) {
  const out = { __name: doc.name, __id: doc.name.split("/").pop() };
  for (const [key, value] of Object.entries(doc.fields || {})) {
    out[key] = parseValue(value);
  }
  return out;
}

async function firestoreFetch(accessToken, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${await response.text()}`);
  }
  return response.json();
}

function intField(value) {
  return { integerValue: String(Number.isFinite(value) ? Math.trunc(value) : 0) };
}

async function main() {
  const accessToken = await getCliAccessToken();
  const runQueryUrl =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    "/databases/(default)/documents:runQuery";

  const queryBody = {
    structuredQuery: {
      from: [{ collectionId: "users" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "role" },
          op: "EQUAL",
          value: { stringValue: "player" },
        },
      },
    },
  };

  const queryResult = await firestoreFetch(accessToken, runQueryUrl, {
    method: "POST",
    body: JSON.stringify(queryBody),
  });

  const players = queryResult
    .filter((row) => row.document)
    .map((row) => parseDoc(row.document));

  const writes = [];
  for (const player of players) {
    const current =
      Number(player.trophies ?? player.cups ?? player.rank ?? player.rankPoints ?? 0) || 0;
    if (player.trophies === undefined || player.cups === undefined) {
      writes.push({
        update: {
          name: player.__name,
          fields: {
            trophies: intField(current),
            cups: intField(current),
          },
        },
        updateMask: { fieldPaths: ["trophies", "cups"] },
      });
    }
  }

  for (let i = 0; i < writes.length; i += 500) {
    const chunk = writes.slice(i, i + 500);
    if (chunk.length === 0) continue;
    await firestoreFetch(
      accessToken,
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
      { method: "POST", body: JSON.stringify({ writes: chunk }) },
    );
  }

  console.log(`Checked ${players.length} players. Backfilled ${writes.length} player docs.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
