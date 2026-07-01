import { describe, it, expect } from 'vitest';
import { loadTokens, saveToken, shouldNotify, TokenRecord } from '../src/tokens';

class MockKV {
  private store: Record<string, string> = {};
  async get(key: string): Promise<string | null> { return this.store[key] ?? null; }
  async put(key: string, value: string): Promise<void> { this.store[key] = value; }
}

const defaultPrefs = { critical: true, major: true, minor: false, info: false };

function makeRecord(token: string, overrides?: Partial<TokenRecord['preferences']>): TokenRecord {
  return { device_token: token, preferences: { ...defaultPrefs, ...overrides }, registered_at: 0 };
}

describe('loadTokens', () => {
  it('returns [] when KV is empty', async () => {
    const kv = new MockKV() as unknown as KVNamespace;
    expect(await loadTokens(kv)).toEqual([]);
  });

  it('returns stored tokens', async () => {
    const kv = new MockKV() as unknown as KVNamespace;
    const record = makeRecord('abc123');
    await saveToken(kv, record);
    expect(await loadTokens(kv)).toEqual([record]);
  });
});

describe('saveToken', () => {
  it('adds a new token', async () => {
    const kv = new MockKV() as unknown as KVNamespace;
    await saveToken(kv, makeRecord('tok1'));
    await saveToken(kv, makeRecord('tok2'));
    const tokens = await loadTokens(kv);
    expect(tokens).toHaveLength(2);
    expect(tokens.map(t => t.device_token)).toContain('tok1');
    expect(tokens.map(t => t.device_token)).toContain('tok2');
  });

  it('updates an existing token instead of duplicating', async () => {
    const kv = new MockKV() as unknown as KVNamespace;
    await saveToken(kv, makeRecord('tok1', { critical: true }));
    await saveToken(kv, makeRecord('tok1', { critical: false }));
    const tokens = await loadTokens(kv);
    expect(tokens).toHaveLength(1);
    expect(tokens[0].preferences.critical).toBe(false);
  });
});

describe('shouldNotify', () => {
  it('returns true when severity matches an enabled preference', () => {
    expect(shouldNotify('Critical', defaultPrefs)).toBe(true);
    expect(shouldNotify('Major', defaultPrefs)).toBe(true);
  });

  it('returns false when severity matches a disabled preference', () => {
    expect(shouldNotify('Minor', defaultPrefs)).toBe(false);
    expect(shouldNotify('Info', defaultPrefs)).toBe(false);
  });

  it('is case-insensitive for severity input', () => {
    expect(shouldNotify('critical', defaultPrefs)).toBe(true);
    expect(shouldNotify('MAJOR', defaultPrefs)).toBe(true);
    expect(shouldNotify('minor', defaultPrefs)).toBe(false);
  });

  it('defaults to false for unknown severity', () => {
    expect(shouldNotify('unknown', defaultPrefs)).toBe(false);
  });
});
