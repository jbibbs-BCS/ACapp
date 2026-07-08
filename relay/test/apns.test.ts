import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { sendPush, APNsPayload, APNsEnv } from '../src/apns';

const testPayload: APNsPayload = {
  aps: { alert: { title: 'AP Disconnected', body: 'Main Office' }, sound: 'default', badge: 1 },
  alert_id: 'alert-001',
  severity: 'Critical',
};

async function generateTestP8(): Promise<string> {
  const keyPair = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign']
  );
  const exported = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
  const bytes = new Uint8Array(exported);
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  const b64 = btoa(str);
  const lines = b64.match(/.{1,64}/g)!.join('\n');
  return `-----BEGIN PRIVATE KEY-----\n${lines}\n-----END PRIVATE KEY-----`;
}

describe('sendPush', () => {
  let fetchMock: ReturnType<typeof vi.fn>;
  let testEnv: APNsEnv;

  beforeEach(async () => {
    fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200 } as Response);
    vi.stubGlobal('fetch', fetchMock);
    testEnv = {
      APNS_KEY_ID: 'ABCDE12345',
      APNS_TEAM_ID: 'FGHIJ67890',
      APNS_PRIVATE_KEY: await generateTestP8(),
      APNS_BUNDLE_ID: 'Bibbs.ArubaCentral',
      APNS_ENVIRONMENT: 'development',
    };
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('calls the sandbox APNs endpoint for development', async () => {
    await sendPush('devicetoken123', testPayload, testEnv);
    expect(fetchMock).toHaveBeenCalledOnce();
    const [url] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain('api.sandbox.push.apple.com');
    expect(url).toContain('devicetoken123');
  });

  it('calls the production APNs endpoint when APNS_ENVIRONMENT is production', async () => {
    await sendPush('devicetoken123', testPayload, { ...testEnv, APNS_ENVIRONMENT: 'production' });
    const [url] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toContain('api.push.apple.com');
    expect(url).not.toContain('sandbox');
  });

  it('sends POST with correct headers', async () => {
    await sendPush('devicetoken123', testPayload, testEnv);
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const headers = init.headers as Record<string, string>;
    expect(headers['apns-topic']).toBe('Bibbs.ArubaCentral');
    expect(headers['apns-push-type']).toBe('alert');
    expect(headers['Content-Type']).toBe('application/json');
    expect(headers['Authorization']).toMatch(/^bearer /);
  });

  it('returns ok:true on 200', async () => {
    const result = await sendPush('devicetoken123', testPayload, testEnv);
    expect(result).toEqual({ ok: true, status: 200 });
  });

  it('returns ok:false on 410 (invalid token)', async () => {
    fetchMock.mockResolvedValueOnce({ ok: false, status: 410 } as Response);
    const result = await sendPush('deadtoken', testPayload, testEnv);
    expect(result).toEqual({ ok: false, status: 410 });
  });
});
