export interface ArubaWebhookPayload {
  nid?: string;
  id?: string;
  name?: string;
  alert_type?: string;
  severity?: string;
  device_serial?: string;
  device_id?: string;
  site_name?: string;
  site?: string;
  description?: string;
  alert_description?: string;
  timestamp?: number;
}

export interface ParsedAlert {
  alertId: string;
  title: string;
  body: string;
  severity: string;
}

const SEVERITY_MAP: Record<string, string> = {
  critical: 'Critical',
  major: 'Major',
  minor: 'Minor',
  info: 'Info',
};

// Notification content is attacker-influenceable (R-6). Strip C0 control chars, DEL, and
// bidi override/isolate formatting (used to spoof/disguise text), then cap length so a
// crafted webhook can't build an oversized or deceptive lock-screen alert.
const TITLE_MAX = 120;
const BODY_MAX = 240;

function clean(s: string, max: number): string {
  // eslint-disable-next-line no-control-regex
  const stripped = s.replace(/[\u0000-\u001F\u007F\u202A-\u202E\u2066-\u2069]/g, '');
  return stripped.slice(0, max);
}

export function parseWebhook(raw: ArubaWebhookPayload): ParsedAlert | null {
  const alertId = raw.nid ?? raw.id;
  if (!alertId) return null;

  const title = raw.name ?? raw.alert_type ?? 'Alert';
  const severity = raw.severity
    ? (SEVERITY_MAP[raw.severity.toLowerCase()] ?? 'Info')
    : 'Info';

  const site = raw.site_name ?? raw.site;
  const device = raw.device_serial ?? raw.device_id;
  const bodyParts = [site, device].filter(Boolean) as string[];
  const body =
    bodyParts.length > 0
      ? bodyParts.join(' — ')
      : (raw.description ?? raw.alert_description ?? '');

  return { alertId, title: clean(title, TITLE_MAX), body: clean(body, BODY_MAX), severity };
}
