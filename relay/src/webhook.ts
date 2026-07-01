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

  return { alertId, title, body, severity };
}
