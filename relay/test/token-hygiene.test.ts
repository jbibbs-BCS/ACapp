import { vi, describe, it, expect, beforeEach } from 'vitest';

// Stub APNs so no real push is attempted; control the returned status per test.
const sendPush = vi.fn();
vi.mock('../src/apns', () => ({ sendPush: (...args: unknown[]) => sendPush(...args) }));

import worker from '../src/index';

class MemKV {
  store: Record<string, string> = {};
  async get(k: string) { return this.store[k] ?? null; }
  async put(k: string, v: string) { this.store[k] = v; }
  async delete(k: string) { delete this.store[k]; }
  async list({ prefix = '' }: { prefix?: string; cursor?: string } = {}) {
    return {
      keys: Object.keys(this.store).filter(k => k.startsWith(prefix)).map(name => ({ name })),
      list_complete: true as const,
    };
  }
}

const TOKEN = 'a'.repeat(64);

function makeEnv(kv: unknown, over: Record<string, unknown> = {}) {
  return {
    DEVICE_TOKENS: kv,
    APNS_KEY_ID: 'k', APNS_TEAM_ID: 't', APNS_PRIVATE_KEY: 'p',
    APNS_BUNDLE_ID: 'b', APNS_ENVIRONMENT: 'development',
    WEBHOOK_SECRET: 'wh', REGISTER_SECRET: 'app',
    ...over,
  } as any;
}

function seed(kv: MemKV, token = TOKEN) {
  kv.store['token:' + token] = JSON.stringify({
    device_token: token,
    preferences: { critical: true, major: true, minor: false, info: false },
    registered_at: 0,
  });
}

function webhookReq() {
  return new Request('https://relay.example/webhook', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Webhook-Secret': 'wh' },
    body: JSON.stringify({ nid: 'a1', name: 'Test', severity: 'critical' }),
  });
}

describe('R-9 — prune tokens on APNs 410/400', () => {
  beforeEach(() => sendPush.mockReset());

  it('deletes the token when APNs returns 410 Unregistered', async () => {
    const kv = new MemKV(); seed(kv);
    sendPush.mockResolvedValue({ ok: false, status: 410 });
    const res = await worker.fetch(webhookReq(), makeEnv(kv));
    expect(res.status).toBe(200);
    expect(sendPush).toHaveBeenCalledTimes(1);
    expect(kv.store['token:' + TOKEN]).toBeUndefined(); // pruned
  });

  it('deletes the token when APNs returns 400 BadDeviceToken', async () => {
    const kv = new MemKV(); seed(kv);
    sendPush.mockResolvedValue({ ok: false, status: 400 });
    await worker.fetch(webhookReq(), makeEnv(kv));
    expect(kv.store['token:' + TOKEN]).toBeUndefined();
  });

  it('keeps the token when APNs returns 200', async () => {
    const kv = new MemKV(); seed(kv);
    sendPush.mockResolvedValue({ ok: true, status: 200 });
    await worker.fetch(webhookReq(), makeEnv(kv));
    expect(kv.store['token:' + TOKEN]).toBeDefined();
  });
});

describe('R-10 — unregister route', () => {
  function unregisterReq(appSecret?: string, token: unknown = TOKEN) {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (appSecret !== undefined) headers['X-App-Secret'] = appSecret;
    return new Request('https://relay.example/unregister', {
      method: 'POST', headers, body: JSON.stringify({ device_token: token }),
    });
  }

  it('removes the token with valid auth', async () => {
    const kv = new MemKV(); seed(kv);
    const res = await worker.fetch(unregisterReq('app'), makeEnv(kv));
    expect(res.status).toBe(200);
    expect(kv.store['token:' + TOKEN]).toBeUndefined();
  });

  it('rejects unregister without auth (403) and does not remove the token', async () => {
    const kv = new MemKV(); seed(kv);
    const res = await worker.fetch(unregisterReq(undefined), makeEnv(kv));
    expect(res.status).toBe(403);
    expect(kv.store['token:' + TOKEN]).toBeDefined();
  });

  it('rejects a malformed token (400)', async () => {
    const kv = new MemKV(); seed(kv);
    const res = await worker.fetch(unregisterReq('app', 'not-a-token'), makeEnv(kv));
    expect(res.status).toBe(400);
  });
});
