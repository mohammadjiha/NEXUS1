const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const projectId = "nexus-90e55";
const apiKey = "AIzaSyBcVcL560bl4OwjTjRPrRNUL-EEHT05Eqg";
const gymId = "GYM-2847";
const gymCode = "1001";
const coachUid = "h73DLMZ825Oy7tjUu53ZqKbcf3F2";
const coachName = "qutaiba";
const importFile = path.join(process.cwd(), "gamma_players_import.json");
const authExportFile = path.join(process.cwd(), "gamma_auth_export.json");

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
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, v(value)]));
}

function parseValue(value) {
  if (!value) return undefined;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("nullValue" in value) return null;
  return undefined;
}

function parseDoc(doc) {
  const out = { __name: doc.name, __id: doc.name.split("/").pop() };
  for (const [key, value] of Object.entries(doc.fields || {})) {
    out[key] = parseValue(value);
  }
  return out;
}

function normText(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function normPhone(value) {
  const digits = String(value || "").replace(/\D+/g, "");
  if (digits.length === 9 && digits.startsWith("7")) return `0${digits}`;
  return digits;
}

function addWrite(writes, collection, id, data) {
  const fieldPaths = Object.keys(data);
  writes.push({
    update: {
      name: docPath(collection, id),
      fields: fields(data),
    },
    updateMask: { fieldPaths },
  });
}

function addNestedWrite(writes, parts, data) {
  writes.push({
    update: {
      name: docPath(...parts),
      fields: fields(data),
    },
    updateMask: { fieldPaths: Object.keys(data) },
  });
}

async function firestoreGet(accessToken, ...parts) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/${docPath(...parts)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`Firestore get failed: ${response.status} ${await response.text()}`);
  }
  return parseDoc(await response.json());
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
    console.log(`Committed writes ${Math.min(i + chunk.length, writes.length)}/${writes.length}`);
  }
}

function loadExportedAuthUsers() {
  if (!fs.existsSync(authExportFile)) return new Map();
  const exported = JSON.parse(fs.readFileSync(authExportFile, "utf8"));
  return new Map(
    (exported.users || [])
      .filter((user) => user.email && user.localId)
      .map((user) => [normText(user.email), user.localId]),
  );
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function createAuthUser(player, usedEmails, authByEmail) {
  const base = player.email.replace("@gamma1001.nexus.app", "");
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const suffix = attempt === 0 ? "" : `.${attempt + 1}`;
    const email = `${base}${suffix}@gamma1001.nexus.app`;
    if (authByEmail.has(normText(email))) {
      usedEmails.add(normText(email));
      return { uid: authByEmail.get(normText(email)), email, created: false };
    }
    if (usedEmails.has(normText(email))) continue;

    await sleep(900);
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email,
          password: player.password,
          returnSecureToken: false,
        }),
      },
    );
    const json = await response.json();
    if (response.ok) {
      usedEmails.add(normText(email));
      authByEmail.set(normText(email), json.localId);
      return { uid: json.localId, email, created: true };
    }
    const message = json?.error?.message || "";
    if (message.includes("EMAIL_EXISTS")) {
      usedEmails.add(normText(email));
      continue;
    }
    if (message.includes("TOO_MANY_ATTEMPTS_TRY_LATER")) {
      throw new Error(`AUTH_RATE_LIMIT:${player.name}:${email}`);
    }
    throw new Error(`Auth create failed for ${player.name}: ${message}`);
  }
  throw new Error(`Could not create unique email for ${player.name}`);
}

function dateFromIso(iso) {
  return new Date(`${iso}T00:00:00.000+03:00`);
}

function statusFor(endIso) {
  const today = new Date("2026-06-07T00:00:00.000+03:00");
  return dateFromIso(endIso) >= today ? "active" : "expired";
}

function userData(player, uid, email, existing) {
  const now = new Date();
  return {
    uid,
    email,
    firstName: player.firstName,
    lastName: player.lastName,
    phone: player.phone,
    gymId,
    gymCode,
    role: "player",
    photoUrl: existing?.photoUrl ?? null,
    authProvider: "password",
    weight: player.weight,
    height: player.height,
    age: player.age,
    goal: player.goal,
    gender: player.gender,
    bodyFat: player.bodyFat,
    dateOfBirth: dateFromIso(player.dateOfBirth),
    muscleMass: player.muscleMass,
    fitnessLevel: player.fitnessLevel,
    trainingMode: player.trainingMode,
    assignedCoachUid: coachUid,
    assignedCoachName: coachName,
    subscriptionPlan: player.subscriptionPlan,
    discountAmount: 0,
    paymentMethod: "cash",
    temporaryPasswordSet: true,
    emailVerified: true,
    updatedAt: now,
    subscriptionStart: dateFromIso(player.subscriptionStart),
    subscriptionEnd: dateFromIso(player.subscriptionEnd),
    totalAmount: 0,
    amountPaid: 0,
    amountRemaining: 0,
    registeredBy: coachUid,
    importedFrom: "gamma_club_xlsx",
    sourceRow: player.sourceRow,
    ...(existing ? {} : { createdAt: now }),
  };
}

function memberData(player, uid, email) {
  return {
    uid,
    email,
    gymId,
    gymCode,
    role: "player",
    displayName: player.name,
    phone: player.phone,
    status: statusFor(player.subscriptionEnd),
    assignedCoachUid: coachUid,
    assignedCoachName: coachName,
    subscriptionPlan: player.subscriptionPlan,
    subscriptionStart: dateFromIso(player.subscriptionStart),
    subscriptionEnd: dateFromIso(player.subscriptionEnd),
    totalAmount: 0,
    discountAmount: 0,
    amountPaid: 0,
    amountRemaining: 0,
    paymentMethod: "cash",
    updatedAt: new Date(),
  };
}

function metricData(player, uid) {
  return {
    userId: uid,
    weight: player.weight,
    previousWeight: 0,
    height: player.height,
    previousHeight: 0,
    bodyFat: player.bodyFat,
    previousBodyFat: 0,
    muscleMass: player.muscleMass,
    previousMuscleMass: 0,
    waist: 0,
    previousWaist: 0,
    initialWeight: player.weight,
    age: player.age,
    dateOfBirth: player.dateOfBirth,
    goal: player.goal,
    fitnessLevel: player.fitnessLevel,
    gender: player.gender,
    trainingMode: player.trainingMode,
    bmr: 0,
    visceralFat: 0,
    fatFreeMass: 0,
    water: 0,
    metabolicAge: 0,
    updatedAt: new Date(),
  };
}

async function main() {
  const players = JSON.parse(fs.readFileSync(importFile, "utf8"));
  const authByEmail = loadExportedAuthUsers();
  const accessToken = await getCliAccessToken();

  const gym = await firestoreGet(accessToken, "gyms", gymId);
  const coach = await firestoreGet(accessToken, "users", coachUid);
  if (!gym) throw new Error(`Gym ${gymId} was not found.`);
  if (!coach) throw new Error(`Coach ${coachUid} was not found.`);
  console.log(`Gym: ${gym.name || gym.gymName || gymId} (${gym.code || gymCode})`);
  console.log(`Coach: ${coach.firstName || ""} ${coach.lastName || ""} / ${coach.email}`);

  const existingUsers = await runQuery(accessToken, {
    from: [{ collectionId: "users" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "gymId" },
        op: "EQUAL",
        value: v(gymId),
      },
    },
    limit: 1000,
  });
  const existingPlayers = existingUsers.filter((user) => user.role === "player");
  const byEmail = new Map();
  const byPhone = new Map();
  const byNamePhone = new Map();
  const usedEmails = new Set();
  for (const user of existingPlayers) {
    if (user.email) {
      byEmail.set(normText(user.email), user);
      usedEmails.add(normText(user.email));
    }
    if (user.phone) byPhone.set(normPhone(user.phone), user);
    byNamePhone.set(`${normText(`${user.firstName || ""} ${user.lastName || ""}`)}|${normPhone(user.phone)}`, user);
  }

  const writes = [];
  let created = 0;
  let updated = 0;
  let linkedFromAuthExport = 0;
  const accounts = [];
  const pending = [];

  for (const player of players) {
    const namePhone = `${normText(player.name)}|${normPhone(player.phone)}`;
    let existing =
      byEmail.get(normText(player.email)) ||
      (player.phone ? byPhone.get(normPhone(player.phone)) : null) ||
      byNamePhone.get(namePhone);

    let uid;
    let email;
    if (existing) {
      uid = existing.uid || existing.__id;
      email = existing.email || player.email;
      updated += 1;
    } else if (authByEmail.has(normText(player.email))) {
      uid = authByEmail.get(normText(player.email));
      email = player.email;
      linkedFromAuthExport += 1;
      accounts.push({ name: player.name, email, password: player.password });
    } else {
      try {
        const authUser = await createAuthUser(player, usedEmails, authByEmail);
        uid = authUser.uid;
        email = authUser.email;
        if (authUser.created) created += 1;
        else linkedFromAuthExport += 1;
        existing = null;
        accounts.push({ name: player.name, email, password: player.password });
      } catch (error) {
        if (String(error.message || "").startsWith("AUTH_RATE_LIMIT:")) {
          pending.push(player);
          continue;
        }
        throw error;
      }
    }

    addWrite(writes, "users", uid, userData(player, uid, email, existing));
    addNestedWrite(writes, ["gyms", gymId, "members", uid], memberData(player, uid, email));
    addNestedWrite(writes, ["gyms", gymId, "memberEmails", email], {
      role: "player",
      status: statusFor(player.subscriptionEnd),
      firstName: player.firstName,
      lastName: player.lastName,
      phone: player.phone,
      assignedCoachUid: coachUid,
      assignedCoachName: coachName,
      addedBy: coachUid,
      updatedAt: new Date(),
    });
    addNestedWrite(writes, ["users", uid, "metrics", "body_composition"], metricData(player, uid));
  }

  await commit(accessToken, writes);
  fs.writeFileSync(
    path.join(process.cwd(), "gamma_import_accounts.json"),
    JSON.stringify(accounts, null, 2),
    "utf8",
  );
  if (pending.length > 0) {
    fs.writeFileSync(
      path.join(process.cwd(), "gamma_import_pending.json"),
      JSON.stringify(pending, null, 2),
      "utf8",
    );
  }
  console.log(
    `Done. Created auth users: ${created}. Linked from Auth export: ${linkedFromAuthExport}. Updated existing players: ${updated}. Pending: ${pending.length}.`,
  );
  console.log(`New account list: ${path.join(process.cwd(), "gamma_import_accounts.json")}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
