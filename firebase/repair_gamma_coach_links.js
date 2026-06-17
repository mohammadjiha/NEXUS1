const { execFileSync } = require("child_process");
const path = require("path");

const projectId = "nexus-90e55";
const gymId = "GYM-2847";
const gymCode = "1001";
const coachUid = "h73DLMZ825Oy7tjUu53ZqKbcf3F2";
const coachName = "qutaiba";

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

function docPath(...parts) {
  return `projects/${projectId}/databases/(default)/documents/${parts.join("/")}`;
}

function v(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(v) } };
  return { stringValue: String(value) };
}

function fields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, v(value)]),
  );
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

function addWrite(writes, parts, data) {
  writes.push({
    update: {
      name: docPath(...parts),
      fields: fields(data),
    },
    updateMask: { fieldPaths: Object.keys(data) },
  });
}

function normalize(value) {
  return String(value || "").trim().toLowerCase();
}

function displayName(user) {
  const name = [user.firstName, user.lastName]
    .filter((part) => String(part || "").trim())
    .join(" ")
    .trim();
  return name || user.email || user.uid || user.__id;
}

function statusFor(user) {
  const end = user.subscriptionEnd ? new Date(user.subscriptionEnd) : null;
  if (end && Number.isFinite(end.getTime()) && end < new Date()) return "expired";
  return "active";
}

function shouldRepair(user) {
  if (normalize(user.role) !== "player") return false;
  if (user.gymId === gymId || String(user.gymCode || "") === gymCode) return true;
  if (String(user.email || "").toLowerCase().endsWith("@gamma1001.nexus.app")) {
    return true;
  }
  if (user.importedFrom === "gamma_club_xlsx") return true;
  return false;
}

async function runQuery(accessToken, structuredQuery) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ structuredQuery }),
    },
  );
  if (!response.ok) {
    throw new Error(`Query failed: ${response.status} ${await response.text()}`);
  }
  return (await response.json()).map((row) => row.document).filter(Boolean).map(parseDoc);
}

async function commit(accessToken, writes) {
  for (let i = 0; i < writes.length; i += 450) {
    const chunk = writes.slice(i, i + 450);
    const response = await fetch(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ writes: chunk }),
      },
    );
    if (!response.ok) {
      throw new Error(`Commit failed: ${response.status} ${await response.text()}`);
    }
    console.log(`Committed ${Math.min(i + chunk.length, writes.length)}/${writes.length}`);
  }
}

async function main() {
  const accessToken = await getCliAccessToken();

  const docs = await runQuery(accessToken, {
    from: [{ collectionId: "users" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "role" },
        op: "EQUAL",
        value: { stringValue: "player" },
      },
    },
    limit: 1000,
  });

  const players = docs.filter(shouldRepair);
  console.log(`Scanned player docs: ${docs.length}`);
  console.log(`Gamma players to repair/link: ${players.length}`);

  const now = new Date();
  const writes = [];

  for (const player of players) {
    const uid = player.uid || player.__id;
    const email = String(player.email || "").trim().toLowerCase();
    const common = {
      gymId,
      gymCode,
      role: "player",
      assignedCoachUid: coachUid,
      assignedCoachName: coachName,
      registeredBy: coachUid,
      updatedAt: now,
    };

    addWrite(writes, ["users", uid], common);
    addWrite(writes, ["gyms", gymId, "members", uid], {
      uid,
      email,
      gymId,
      gymCode,
      role: "player",
      displayName: displayName(player),
      phone: player.phone || "",
      status: statusFor(player),
      assignedCoachUid: coachUid,
      assignedCoachName: coachName,
      subscriptionPlan: player.subscriptionPlan || "Gamma Membership",
      totalAmount: Number(player.totalAmount || 0),
      discountAmount: Number(player.discountAmount || 0),
      amountPaid: Number(player.amountPaid || 0),
      amountRemaining: Number(player.amountRemaining || 0),
      paymentMethod: player.paymentMethod || "cash",
      updatedAt: now,
    });

    if (email) {
      addWrite(writes, ["gyms", gymId, "memberEmails", email], {
        role: "player",
        status: statusFor(player),
        firstName: player.firstName || "",
        lastName: player.lastName || "",
        phone: player.phone || "",
        assignedCoachUid: coachUid,
        assignedCoachName: coachName,
        addedBy: coachUid,
        updatedAt: now,
      });
    }
  }

  if (writes.length > 0) await commit(accessToken, writes);

  const verify = await runQuery(accessToken, {
    from: [{ collectionId: "users" }],
    where: {
      compositeFilter: {
        op: "AND",
        filters: [
          {
            fieldFilter: {
              field: { fieldPath: "gymId" },
              op: "EQUAL",
              value: { stringValue: gymId },
            },
          },
          {
            fieldFilter: {
              field: { fieldPath: "role" },
              op: "EQUAL",
              value: { stringValue: "player" },
            },
          },
          {
            fieldFilter: {
              field: { fieldPath: "assignedCoachUid" },
              op: "EQUAL",
              value: { stringValue: coachUid },
            },
          },
        ],
      },
    },
    limit: 1000,
  });

  console.log(`Verified linked players for qutaiba: ${verify.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
