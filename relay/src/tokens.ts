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

// One KV entry per token (R-4/R-5). This removes the single `registered_tokens` blob
// (unbounded growth, KV value-size ceiling) and the non-atomic read-modify-write race:
// each registration is an independent `put`, so concurrent writers no longer clobber
// each other. Trade-off: webhook fan-out now does list + N gets — fine for moderate N;
// move to a Durable Object index if the token count grows large.
const PREFIX = 'token:';

export async function loadTokens(kv: KVNamespace): Promise<TokenRecord[]> {
  const out: TokenRecord[] = [];
  let cursor: string | undefined;
  do {
    const page = await kv.list({ prefix: PREFIX, cursor });
    for (const key of page.keys) {
      const raw = await kv.get(key.name);
      if (raw) {
        try { out.push(JSON.parse(raw) as TokenRecord); } catch { /* skip corrupt entry */ }
      }
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return out;
}

export async function saveToken(kv: KVNamespace, record: TokenRecord): Promise<void> {
  // Same key for the same token => upsert, no duplicates, no read-modify-write.
  await kv.put(PREFIX + record.device_token, JSON.stringify(record));
}

export async function deleteToken(kv: KVNamespace, token: string): Promise<void> {
  await kv.delete(PREFIX + token);
}

export function shouldNotify(
  severity: string,
  prefs: TokenRecord['preferences']
): boolean {
  const key = severity.toLowerCase() as keyof typeof prefs;
  return prefs[key] ?? false;
}
