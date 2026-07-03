import { loadTokens, saveToken, deleteToken, shouldNotify, TokenRecord } from './tokens';
import { parseWebhook, ArubaWebhookPayload } from './webhook';
import { sendPush, APNsPayload } from './apns';

export interface Env {
  DEVICE_TOKENS: KVNamespace;
  APNS_KEY_ID: string;
  APNS_TEAM_ID: string;
  APNS_PRIVATE_KEY: string;
  APNS_BUNDLE_ID: string;
  APNS_ENVIRONMENT: string;
  WEBHOOK_SECRET: string;
  REGISTER_SECRET: string;
}

async function handleRegister(request: Request, env: Env): Promise<Response> {
  // Authenticate the caller (R-2). Fail CLOSED if the shared secret isn't configured.
  // NOTE: a shared secret shipped in the app is a stopgap; App Attest / DeviceCheck is
  // the robust control (tracked separately).
  if (!env.REGISTER_SECRET) {
    return new Response('Server misconfigured', { status: 503 });
  }
  if (!(await timingSafeEqual(request.headers.get('X-App-Secret') ?? '', env.REGISTER_SECRET))) {
    return new Response('Forbidden', { status: 403 });
  }

  const raw = await readLimitedText(request);
  if (raw === null) return new Response('Payload too large', { status: 413 });
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  const b = body as Record<string, unknown>;
  const token = b['device_token'];
  // Validate token shape (R-7): APNs device tokens are hex, 64+ chars. Reject anything else
  // so garbage/oversized/metacharacter tokens can't be stored or smuggled toward APNs.
  if (typeof token !== 'string' || !/^[0-9a-fA-F]{64,200}$/.test(token)) {
    return new Response('Invalid device_token', { status: 400 });
  }

  const prefs = (b['preferences'] as Record<string, boolean>) ?? {};
  const record: TokenRecord = {
    device_token: token,
    preferences: {
      critical: prefs['critical'] ?? true,
      major:    prefs['major']    ?? true,
      minor:    prefs['minor']    ?? false,
      info:     prefs['info']     ?? false,
    },
    registered_at: Date.now(),
  };

  await saveToken(env.DEVICE_TOKENS, record);
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Reject oversized request bodies before JSON parsing (R-10). Device tokens + prefs and
// alert payloads are small; anything large is abuse. Fast-path on Content-Length when the
// runtime provides it, then enforce on the actual body length. Returns null if too large.
const MAX_BODY_BYTES = 16 * 1024;
async function readLimitedText(request: Request): Promise<string | null> {
  const len = request.headers.get('Content-Length');
  if (len !== null && Number(len) > MAX_BODY_BYTES) return null;
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) return null;
  return text;
}

// Constant-time secret comparison (R-3). Hashing both sides to a fixed-length SHA-256
// digest before comparing makes the compare independent of the secret's length/prefix,
// closing the byte-by-byte timing side channel of `!==`.
async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const enc = new TextEncoder();
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(a)),
    crypto.subtle.digest('SHA-256', enc.encode(b)),
  ]);
  const va = new Uint8Array(ha);
  const vb = new Uint8Array(hb);
  let diff = 0;
  for (let i = 0; i < va.length; i++) diff |= va[i] ^ vb[i];
  return diff === 0;
}

async function handleWebhook(request: Request, env: Env): Promise<Response> {
  // Fail CLOSED (R-1): a missing/empty WEBHOOK_SECRET must never disable auth. Reject
  // outright rather than skipping the check, so a misconfigured deploy can't be pushed to.
  if (!env.WEBHOOK_SECRET) {
    return new Response('Server misconfigured', { status: 503 });
  }
  const provided = request.headers.get('X-Webhook-Secret') ?? '';
  if (!(await timingSafeEqual(provided, env.WEBHOOK_SECRET))) {   // R-3: constant-time
    return new Response('Forbidden', { status: 403 });
  }

  const raw = await readLimitedText(request);
  if (raw === null) return new Response('Payload too large', { status: 413 });
  let body: ArubaWebhookPayload;
  try {
    body = JSON.parse(raw) as ArubaWebhookPayload;
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  const alert = parseWebhook(body);
  if (!alert) {
    return new Response('Missing alert ID', { status: 400 });
  }

  const tokens = await loadTokens(env.DEVICE_TOKENS);
  const eligible = tokens.filter(t => shouldNotify(alert.severity, t.preferences));

  const payload: APNsPayload = {
    aps: {
      alert: { title: alert.title, body: alert.body },
      sound: 'default',
      badge: 1,
    },
    alert_id: alert.alertId,
    severity: alert.severity,
  };

  // Prune stale tokens on APNs 410 (Unregistered) / 400 (BadDeviceToken) so they don't
  // accumulate forever (R-9 / token hygiene, ties to R-4).
  await Promise.allSettled(
    eligible.map(async t => {
      const r = await sendPush(t.device_token, payload, env);
      if (r.status === 410 || r.status === 400) {
        await deleteToken(env.DEVICE_TOKENS, t.device_token);
      }
    })
  );

  return new Response(
    JSON.stringify({ ok: true, recipients: eligible.length }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// R-9: allow a device to remove its token (token hygiene). Authenticated like /register.
async function handleUnregister(request: Request, env: Env): Promise<Response> {
  if (!env.REGISTER_SECRET) {
    return new Response('Server misconfigured', { status: 503 });
  }
  if (!(await timingSafeEqual(request.headers.get('X-App-Secret') ?? '', env.REGISTER_SECRET))) {
    return new Response('Forbidden', { status: 403 });
  }

  const raw = await readLimitedText(request);
  if (raw === null) return new Response('Payload too large', { status: 413 });
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  const token = (body as Record<string, unknown>)['device_token'];
  if (typeof token !== 'string' || !/^[0-9a-fA-F]{64,200}$/.test(token)) {
    return new Response('Invalid device_token', { status: 400 });
  }

  await deleteToken(env.DEVICE_TOKENS, token);
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/register') {
      return handleRegister(request, env);
    }
    if (request.method === 'POST' && url.pathname === '/webhook') {
      return handleWebhook(request, env);
    }
    if (request.method === 'POST' && url.pathname === '/unregister') {
      return handleUnregister(request, env);
    }
    return new Response('Not Found', { status: 404 });
  },
};
