export interface Env {
  DEVICE_TOKENS: KVNamespace;
  APNS_KEY_ID: string;
  APNS_TEAM_ID: string;
  APNS_PRIVATE_KEY: string;
  APNS_BUNDLE_ID: string;
  APNS_ENVIRONMENT: string;
  WEBHOOK_SECRET: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/register') {
      return new Response('TODO', { status: 200 });
    }
    if (request.method === 'POST' && url.pathname === '/webhook') {
      return new Response('TODO', { status: 200 });
    }
    return new Response('Not Found', { status: 404 });
  },
};
