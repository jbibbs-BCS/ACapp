export interface APNsPayload {
  aps: {
    alert: { title: string; body: string };
    sound: string;
    badge: number;
  };
  alert_id: string;
  severity: string;
}

export interface APNsEnv {
  APNS_KEY_ID: string;
  APNS_TEAM_ID: string;
  APNS_PRIVATE_KEY: string;
  APNS_BUNDLE_ID: string;
  APNS_ENVIRONMENT: string;
}

function arrayBufferToBase64url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function encodeJSONPart(obj: unknown): string {
  return arrayBufferToBase64url(
    new TextEncoder().encode(JSON.stringify(obj)).buffer as ArrayBuffer
  );
}

async function importAPNsKey(p8: string): Promise<CryptoKey> {
  const pem = p8
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(pem);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );
}

async function makeAPNsJWT(
  keyId: string,
  teamId: string,
  privateKey: CryptoKey
): Promise<string> {
  const header = encodeJSONPart({ alg: 'ES256', kid: keyId });
  const payload = encodeJSONPart({ iss: teamId, iat: Math.floor(Date.now() / 1000) });
  const data = new TextEncoder().encode(`${header}.${payload}`);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, privateKey, data);
  return `${header}.${payload}.${arrayBufferToBase64url(sig)}`;
}

export async function sendPush(
  token: string,
  payload: APNsPayload,
  env: APNsEnv
): Promise<{ ok: boolean; status: number }> {
  const privateKey = await importAPNsKey(env.APNS_PRIVATE_KEY);
  const jwt = await makeAPNsJWT(env.APNS_KEY_ID, env.APNS_TEAM_ID, privateKey);
  const host =
    env.APNS_ENVIRONMENT === 'production'
      ? 'api.push.apple.com'
      : 'api.sandbox.push.apple.com';
  const resp = await fetch(`https://${host}/3/device/${token}`, {
    method: 'POST',
    headers: {
      Authorization: `bearer ${jwt}`,
      'apns-topic': env.APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  return { ok: resp.ok, status: resp.status };
}
