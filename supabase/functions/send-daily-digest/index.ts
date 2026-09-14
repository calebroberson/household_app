// Sends a personalized "N chores due today" APNs push to every
// registered device. Triggered daily by Supabase Cron (pg_cron) -- see
// the schedule SQL in CLAUDE.md/the plan. This function only READS
// chore_occurrences; it never creates/mutates occurrence rows -- that
// stays exclusively client-side in occurrence_generator.dart.
//
// A user's count = occurrences due today (due_date <= today), not
// completed, not skipped, where assigned_to is either them (fixed
// assignee, or their current rotate turn) or null (an 'anyone' chore --
// counted for everyone, matching Today's "Anyone" section being shared
// responsibility, not a nag directed at one person).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "jsr:@panva/jose@6";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

interface DeviceTokenRow {
  user_id: string;
  household_id: string;
  token: string;
}

interface OccurrenceRow {
  household_id: string;
  assigned_to: string | null;
}

let cachedJwt: { token: string; issuedAt: number } | null = null;

// APNs provider JWTs are valid up to 1 hour; reuse within a run instead
// of re-signing per push, regenerate once it's getting stale.
async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < 1800) {
    return cachedJwt.token;
  }
  const privateKey = await importPKCS8(APNS_PRIVATE_KEY, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: APNS_KEY_ID })
    .setIssuer(APNS_TEAM_ID)
    .setIssuedAt(now)
    .sign(privateKey);
  cachedJwt = { token, issuedAt: now };
  return token;
}

async function sendPush(deviceToken: string, message: string): Promise<Response> {
  const jwt = await getApnsJwt();
  return fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "5",
    },
    body: JSON.stringify({ aps: { alert: message, sound: "default" } }),
  });
}

Deno.serve(async (_req) => {
  const today = new Date().toISOString().slice(0, 10);

  const { data: tokens, error: tokensError } = await supabase
    .from("device_tokens")
    .select("user_id, household_id, token");
  if (tokensError) {
    return new Response(JSON.stringify({ error: tokensError.message }), { status: 500 });
  }
  const deviceTokens = (tokens ?? []) as DeviceTokenRow[];
  if (deviceTokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, reason: "no registered devices" }));
  }

  const householdIds = [...new Set(deviceTokens.map((t) => t.household_id))];

  const { data: occurrences, error: occurrencesError } = await supabase
    .from("chore_occurrences")
    .select("household_id, assigned_to")
    .in("household_id", householdIds)
    .lte("due_date", today)
    .is("completed_at", null)
    .eq("skipped", false);
  if (occurrencesError) {
    return new Response(JSON.stringify({ error: occurrencesError.message }), { status: 500 });
  }
  const dueOccurrences = (occurrences ?? []) as OccurrenceRow[];

  const tokensByUser = new Map<string, { householdId: string; deviceTokens: string[] }>();
  for (const row of deviceTokens) {
    const existing = tokensByUser.get(row.user_id);
    if (existing) {
      existing.deviceTokens.push(row.token);
    } else {
      tokensByUser.set(row.user_id, {
        householdId: row.household_id,
        deviceTokens: [row.token],
      });
    }
  }

  let sent = 0;
  const staleTokens: string[] = [];

  for (const [userId, { householdId, deviceTokens: userTokens }] of tokensByUser) {
    const count = dueOccurrences.filter(
      (o) => o.household_id === householdId && (o.assigned_to === userId || o.assigned_to === null),
    ).length;
    if (count === 0) continue;

    const message = `You have ${count} chore${count === 1 ? "" : "s"} due today.`;

    for (const deviceToken of userTokens) {
      const res = await sendPush(deviceToken, message);
      if (res.status === 410) {
        staleTokens.push(deviceToken);
      } else if (res.ok) {
        sent++;
      }
    }
  }

  if (staleTokens.length > 0) {
    await supabase.from("device_tokens").delete().in("token", staleTokens);
  }

  return new Response(JSON.stringify({ sent, pruned: staleTokens.length }));
});
