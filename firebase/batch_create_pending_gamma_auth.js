const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { execFileSync } = require("child_process");

const projectId = "nexus-90e55";
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
  await requireAuth({
    user: account.user,
    tokens: account.tokens,
    project: projectId,
  });
  return apiv2.getAccessToken();
}

function uid() {
  return crypto.randomBytes(15).toString("base64url");
}

async function main() {
  const players = JSON.parse(fs.readFileSync(importFile, "utf8"));
  const exported = JSON.parse(fs.readFileSync(authExportFile, "utf8"));
  const existingEmails = new Set(
    (exported.users || []).map((user) => String(user.email || "").toLowerCase()),
  );
  const pending = players.filter(
    (player) => !existingEmails.has(String(player.email).toLowerCase()),
  );
  console.log(`Pending auth users: ${pending.length}`);
  if (pending.length === 0) return;

  const accessToken = await getCliAccessToken();
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchCreate`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        users: pending.map((player) => ({
          localId: uid(),
          email: player.email,
          rawPassword: player.password,
          displayName: player.name,
          emailVerified: true,
          disabled: false,
        })),
      }),
    },
  );
  const json = await response.json();
  console.log(JSON.stringify(json, null, 2));
  if (!response.ok || json.error?.length) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
