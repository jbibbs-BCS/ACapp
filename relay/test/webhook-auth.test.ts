import { describe, it, expect } from 'vitest';
import worker from '../src/index';

// Regression guard for finding R-1 (webhook auth fail-open). Asserts the HARDENED
// behavior: a missing/empty WEBHOOK_SECRET fails CLOSED (503), and requests are only
// accepted with the correct secret. Before the fix, the unset case returned 200.

const kvStub = {
  get: async () => null,                                  // loadTokens -> [] (no sendPush)
  put: async () => {},
  delete: async () => {},
  list: async () => ({ keys: [], list_complete: true }),
};

function makeEnv(overrides: Record<string, unknown> = {}) {
  return {
    DEVICE_TOKENS: kvStub,
    APNS_KEY_ID: 'k', APNS_TEAM_ID: 't', APNS_PRIVATE_KEY: 'p',
    APNS_BUNDLE_ID: 'b', APNS_ENVIRONMENT: 'development',
    WEBHOOK_SECRET: 'correct-secret',
    ...overrides,
  } as any;
}

function webhookRequest(secret?: string) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (secret !== undefined) headers['X-Webhook-Secret'] = secret;
  return new Request('https://relay.example/webhook', {
    method: 'POST',
    headers,
    body: JSON.stringify({ nid: 'a1', name: 'Test', severity: 'critical' }),
  });
}

describe('handleWebhook auth — R-1 fail-closed', () => {
  it('returns 503 when WEBHOOK_SECRET is unset (fail closed, NOT fail open)', async () => {
    const res = await worker.fetch(webhookRequest('anything'), makeEnv({ WEBHOOK_SECRET: '' }));
    expect(res.status).toBe(503);
  });

  it('returns 403 when the secret is set but the header is missing', async () => {
    const res = await worker.fetch(webhookRequest(undefined), makeEnv());
    expect(res.status).toBe(403);
  });

  it('returns 403 when the secret is set but the header is wrong', async () => {
    const res = await worker.fetch(webhookRequest('wrong'), makeEnv());
    expect(res.status).toBe(403);
  });

  it('returns 200 when the correct secret is provided', async () => {
    const res = await worker.fetch(webhookRequest('correct-secret'), makeEnv());
    expect(res.status).toBe(200);
  });

  // R-3: constant-time compare must still reject correctly regardless of
  // length/prefix relationship to the real secret (no leak, no bypass).
  it('rejects a correct-prefix-but-shorter secret (403)', async () => {
    const res = await worker.fetch(webhookRequest('correct-secre'), makeEnv());
    expect(res.status).toBe(403);
  });

  it('rejects a longer secret with the correct prefix (403)', async () => {
    const res = await worker.fetch(webhookRequest('correct-secret-plus-extra'), makeEnv());
    expect(res.status).toBe(403);
  });

  it('rejects an empty provided secret (403)', async () => {
    const res = await worker.fetch(webhookRequest(''), makeEnv());
    expect(res.status).toBe(403);
  });
});
