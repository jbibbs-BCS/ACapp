import { loadTokens, saveToken, shouldNotify, TokenRecord } from './tokens';
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
}

async function handleRegister(request: Request, env: Env): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  const b = body as Record<string, unknown>;
  const token = b['device_token'];
  if (typeof token !== 'string' || !token) {
    return new Response('Missing device_token', { status: 400 });
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

async function handleWebhook(request: Request, env: Env): Promise<Response> {
  if (env.WEBHOOK_SECRET) {
    const provided = request.headers.get('X-Webhook-Secret') ?? '';
    if (provided !== env.WEBHOOK_SECRET) {
      return new Response('Forbidden', { status: 403 });
    }
  }

  let body: ArubaWebhookPayload;
  try {
    body = (await request.json()) as ArubaWebhookPayload;
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

  await Promise.allSettled(
    eligible.map(t => sendPush(t.device_token, payload, env))
  );

  return new Response(
    JSON.stringify({ ok: true, recipients: eligible.length }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
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
    return new Response('Not Found', { status: 404 });
  },
};
