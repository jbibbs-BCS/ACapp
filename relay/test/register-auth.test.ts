import { describe, it, expect } from 'vitest';
import worker from '../src/index';

// Regression guard for findings R-2 (unauthenticated /register) and R-7 (no token-shape
// validation). Asserts the HARDENED behavior: caller must present X-App-Secret, and only
// well-formed APNs device tokens (hex, 64+ chars) are accepted. Before the fix, any caller
// could register any string.

const kvStub = {
  get: async () => null,
  put: async () => {},
  delete: async () => {},
  list: async () => ({ keys: [], list_complete: true }),
};

const VALID_TOKEN = 'a'.repeat(64); // 64 hex chars

function makeEnv(overrides: Record<string, unknown> = {}) {
  return {
    DEVICE_TOKENS: kvStub,
    APNS_KEY_ID: 'k', APNS_TEAM_ID: 't', APNS_PRIVATE_KEY: 'p',
    APNS_BUNDLE_ID: 'b', APNS_ENVIRONMENT: 'development',
    WEBHOOK_SECRET: 'wh', REGISTER_SECRET: 'app-secret',
    ...overrides,
  } as any;
}

function registerRequest(appSecret: string | undefined, token: unknown = VALID_TOKEN) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (appSecret !== undefined) headers['X-App-Secret'] = appSecret;
  return new Request('https://relay.example/register', {
    method: 'POST',
    headers,
    body: JSON.stringify({ device_token: token }),
  });
}

describe('handleRegister auth — R-2', () => {
  it('returns 503 when REGISTER_SECRET is unset (fail closed)', async () => {
    const res = await worker.fetch(registerRequest('anything'), makeEnv({ REGISTER_SECRET: '' }));
    expect(res.status).toBe(503);
  });

  it('returns 403 when X-App-Secret header is missing', async () => {
    const res = await worker.fetch(registerRequest(undefined), makeEnv());
    expect(res.status).toBe(403);
  });

  it('returns 403 when X-App-Secret is wrong', async () => {
    const res = await worker.fetch(registerRequest('wrong'), makeEnv());
    expect(res.status).toBe(403);
  });

  it('returns 200 with correct secret and a valid token', async () => {
    const res = await worker.fetch(registerRequest('app-secret'), makeEnv());
    expect(res.status).toBe(200);
  });
});

describe('handleRegister token-shape validation — R-7', () => {
  const cases: [string, unknown][] = [
    ['non-hex string',   'not-a-real-token'],
    ['path traversal',   '../../etc/passwd'],
    ['CRLF injection',   'tok%0d%0ainjected'],
    ['too short',        'abcdef'],
    ['oversized (500 A)', 'A'.repeat(500)],
    ['non-string',       12345],
  ];
  for (const [label, token] of cases) {
    it(`rejects ${label} with 400`, async () => {
      const res = await worker.fetch(registerRequest('app-secret', token), makeEnv());
      expect(res.status).toBe(400);
    });
  }

  it('accepts a canonical 64-hex token', async () => {
    const res = await worker.fetch(registerRequest('app-secret', VALID_TOKEN), makeEnv());
    expect(res.status).toBe(200);
  });
});
