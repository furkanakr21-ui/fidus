// TEFAS/BEFAS proxy — Flutter istemcisi bu fonksiyonu çağırır,
// sunucu RapidAPI'ye istek atar. RapidAPI key sunucuda gizli kalır.

const RAPIDAPI_KEY = Deno.env.get("RAPIDAPI_KEY") ?? "";
const RAPIDAPI_HOST = "tefas-api.p.rapidapi.com";
const RAPIDAPI_BASE = `https://${RAPIDAPI_HOST}`;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS });
  }

  const incomingUrl = new URL(req.url);

  // /functions/v1/proxy-tefas/api/v1/funds/returns/1?size=200
  // → path = /api/v1/funds/returns/1
  const pathMatch = incomingUrl.pathname.match(/\/proxy-tefas(\/.*)?$/);
  const path = pathMatch?.[1] ?? "/";
  const search = incomingUrl.search;

  const targetUrl = `${RAPIDAPI_BASE}${path}${search}`;

  try {
    const res = await fetch(targetUrl, {
      method: req.method,
      headers: {
        "x-rapidapi-key": RAPIDAPI_KEY,
        "x-rapidapi-host": RAPIDAPI_HOST,
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(25000),
    });

    const body = await res.text();
    return new Response(body, {
      status: res.status,
      headers: {
        ...CORS,
        "Content-Type": res.headers.get("content-type") ?? "application/json",
      },
    });
  } catch (err) {
    console.error("proxy-tefas hata:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
