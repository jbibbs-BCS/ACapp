import { describe, it, expect } from 'vitest';
import { parseWebhook, ArubaWebhookPayload } from '../src/webhook';

const fullPayload: ArubaWebhookPayload = {
  nid: 'alert-001',
  name: 'AP Disconnected',
  severity: 'critical',
  device_serial: 'CNF1234567',
  site_name: 'Main Office',
  description: 'AP-305 lost uplink',
};

describe('parseWebhook', () => {
  it('returns null when no alert ID is present', () => {
    expect(parseWebhook({})).toBeNull();
  });

  it('uses nid as alertId', () => {
    expect(parseWebhook(fullPayload)?.alertId).toBe('alert-001');
  });

  it('falls back to id when nid is missing', () => {
    const result = parseWebhook({ ...fullPayload, nid: undefined, id: 'alert-002' });
    expect(result?.alertId).toBe('alert-002');
  });

  it('maps name to title', () => {
    expect(parseWebhook(fullPayload)?.title).toBe('AP Disconnected');
  });

  it('falls back to alert_type when name is missing', () => {
    const result = parseWebhook({ ...fullPayload, name: undefined, alert_type: 'AP_DOWN' });
    expect(result?.title).toBe('AP_DOWN');
  });

  it('capitalizes severity to match iOS AlertSeverity rawValue', () => {
    expect(parseWebhook(fullPayload)?.severity).toBe('Critical');
    expect(parseWebhook({ ...fullPayload, severity: 'major' })?.severity).toBe('Major');
    expect(parseWebhook({ ...fullPayload, severity: 'minor' })?.severity).toBe('Minor');
    expect(parseWebhook({ ...fullPayload, severity: 'info' })?.severity).toBe('Info');
  });

  it('defaults to Info for unknown severity', () => {
    expect(parseWebhook({ ...fullPayload, severity: 'unknown' })?.severity).toBe('Info');
  });

  it('builds body from site_name and device_serial', () => {
    expect(parseWebhook(fullPayload)?.body).toBe('Main Office — CNF1234567');
  });

  it('builds body from site_name alone when device_serial is missing', () => {
    const result = parseWebhook({ ...fullPayload, device_serial: undefined });
    expect(result?.body).toBe('Main Office');
  });

  it('falls back to description when no site or device present', () => {
    const result = parseWebhook({ nid: 'x', severity: 'info', description: 'Something happened' });
    expect(result?.body).toBe('Something happened');
  });

  it('falls back to alert_description when description is also missing', () => {
    const result = parseWebhook({ nid: 'x', severity: 'info', alert_description: 'Fallback text' });
    expect(result?.body).toBe('Fallback text');
  });
});

// R-6: cap + sanitize attacker-influenceable notification content.
describe('parseWebhook content sanitization (R-6)', () => {
  it('strips C0 control chars and DEL from the title', () => {
    const result = parseWebhook({ nid: 'x', name: 'Alerter' });
    expect(result?.title).toBe('Alerter');
  });

  it('strips bidi override/isolate formatting from the title', () => {
    const result = parseWebhook({ nid: 'x', name: 'Alert‮gnp.exe‬' });
    expect(result?.title).toBe('Alertgnp.exe');
  });

  it('caps an overlong title at 120 chars', () => {
    const result = parseWebhook({ nid: 'x', name: 'A'.repeat(5000) });
    expect(result?.title.length).toBe(120);
  });

  it('caps an overlong body at 240 chars', () => {
    const result = parseWebhook({ nid: 'x', description: 'B'.repeat(5000) });
    expect(result?.body?.length).toBe(240);
  });

  it('strips newlines and tabs from the body', () => {
    const result = parseWebhook({ nid: 'x', description: 'line1\nline2\ttail' });
    expect(result?.body).toBe('line1line2tail');
  });

  it('leaves normal content (incl. the em-dash separator) intact', () => {
    const result = parseWebhook({
      nid: 'x', name: 'AP Disconnected',
      site_name: 'Main Office', device_serial: 'CNF1234567',
    });
    expect(result?.title).toBe('AP Disconnected');
    expect(result?.body).toBe('Main Office — CNF1234567');
  });
});
