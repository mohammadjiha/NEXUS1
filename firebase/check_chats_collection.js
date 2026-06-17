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
  await requireAuth({
    user: account.user,
    tokens: account.tokens,
    project: projectId,
  });
  return apiv2.getAccessToken();
}

async function main() {
  const accessToken = await getCliAccessToken();
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/chats?pageSize=10`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  const json = await response.json();
  if (!response.ok) {
    console.log(`Failed: ${response.status}`);
    console.log(JSON.stringify(json, null, 2));
    process.exit(1);
  }
  const chats = json.documents || [];
  console.log(`chats_count_sample=${chats.length}`);
  for (const chat of chats) {
    console.log(chat.name.split("/").pop());
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
