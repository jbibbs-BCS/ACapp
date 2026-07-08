import { describe, it, expect } from 'vitest';
import worker from '../src/index';

// Regression guard for R-10 (no application-level body-size guard). Asserts oversized
// bodies are rejected with 413 before parsing, on every POST route.

const kvStub = {
  get: async () => null,
  put: async () => {},
  delete: async () => {},
  list: async () => ({ keys: [], list_complete: true }),
};

function makeEnv() {
  return {
    DEVICE_TOKENS: kvStub,
    APNS_KEY_ID: 'k', APNS_TEAM_ID: 't', APNS_PRIVATE_KEY: 'p',
    APNS_BUNDLE_ID: 'b', APNS_ENVIRONMENT: 'development',
    WEBHOOK_SECRET: 'wh', REGISTER_SECRET: 'app',
  } as any;
}

const BIG_PAD = 'x'.repeat(20000); // pushes body past the 16 KB cap

describe('R-10 — body-size guard (413)', () => {
  it('rejects an oversized /register body', async () => {
    const req = new Request('https://relay.example/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-App-Secret': 'app' },
      body: JSON.stringify({ device_token: 'a'.repeat(64), pad: BIG_PAD }),
    });
    expect((await worker.fetch(req, makeEnv())).status).toBe(413);
  });

  it('rejects an oversized /webhook body', async () => {
    const req = new Request('https://relay.example/webhook', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Webhook-Secret': 'wh' },
      body: JSON.stringify({ nid: 'a', name: 'x', pad: BIG_PAD }),
    });
    expect((await worker.fetch(req, makeEnv())).status).toBe(413);
  });

  it('rejects an oversized /unregister body', async () => {
    const req = new Request('https://relay.example/unregister', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-App-Secret': 'app' },
      body: JSON.stringify({ device_token: 'a'.repeat(64), pad: BIG_PAD }),
    });
    expect((await worker.fetch(req, makeEnv())).status).toBe(413);
  });

  it('allows a normal-size /register body (200)', async () => {
    const req = new Request('https://relay.example/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-App-Secret': 'app' },
      body: JSON.stringify({ device_token: 'a'.repeat(64) }),
    });
    expect((await worker.fetch(req, makeEnv())).status).toBe(200);
  });
});
