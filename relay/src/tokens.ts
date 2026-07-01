export interface TokenRecord {
  device_token: string;
  preferences: {
    critical: boolean;
    major: boolean;
    minor: boolean;
    info: boolean;
  };
  registered_at: number;
}

const TOKENS_KEY = 'registered_tokens';

export async function loadTokens(kv: KVNamespace): Promise<TokenRecord[]> {
  const raw = await kv.get(TOKENS_KEY);
  if (!raw) return [];
  try {
    return JSON.parse(raw) as TokenRecord[];
  } catch {
    return [];
  }
}

export async function saveToken(kv: KVNamespace, record: TokenRecord): Promise<void> {
  const tokens = await loadTokens(kv);
  const idx = tokens.findIndex(t => t.device_token === record.device_token);
  if (idx >= 0) {
    tokens[idx] = record;
  } else {
    tokens.push(record);
  }
  await kv.put(TOKENS_KEY, JSON.stringify(tokens));
}

export function shouldNotify(
  severity: string,
  prefs: TokenRecord['preferences']
): boolean {
  const key = severity.toLowerCase() as keyof typeof prefs;
  return prefs[key] ?? false;
}
