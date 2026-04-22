import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const RAPIDAPI_KEY = Deno.env.get("RAPIDAPI_KEY") ?? "";
const RAPIDAPI_HOST = "tefas-api.p.rapidapi.com";
const RAPIDAPI_BASE = `https://${RAPIDAPI_HOST}`;

const HEADERS = {
  "x-rapidapi-key": RAPIDAPI_KEY,
  "x-rapidapi-host": RAPIDAPI_HOST,
  "Content-Type": "application/json",
};

// RapidAPI search endpoint: /api/v1/funds/search?q={code}&size=10
// lastPrice alanını içeriyor
async function fetchFundPrice(code: string): Promise<number | null> {
  if (!RAPIDAPI_KEY) return null;
  try {
    const url = `${RAPIDAPI_BASE}/api/v1/funds/search?q=${encodeURIComponent(code)}&size=10`;
    const res = await fetch(url, {
      headers: HEADERS,
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) {
      console.warn(`${code} RapidAPI ${res.status}`);
      return null;
    }
    const body = await res.json();
    const list: Record<string, unknown>[] = Array.isArray(body)
      ? body
      : (body?.data as Record<string, unknown>[]) ?? [];

    // Tam eşleşen fonu bul (fundCode veya code alanına göre)
    const exact = list.find(
      (f) => String(f["fundCode"] ?? f["code"] ?? "").toUpperCase() === code.toUpperCase(),
    ) ?? list[0];

    if (!exact) return null;

    const raw = exact["lastPrice"] ?? exact["price"] ?? exact["nav"] ?? exact["FIYAT"];
    if (raw === null || raw === undefined) return null;
    const price = parseFloat(String(raw));
    return isFinite(price) && price > 0 ? price : null;
  } catch (e) {
    console.warn(`${code} fiyat hatası:`, e);
    return null;
  }
}

Deno.serve(async (_req) => {
  try {
    const { data: assets, error } = await supabase
      .from("assets")
      .select("api_id, api_source")
      .in("api_source", ["tefas", "befas"]);

    if (error) throw error;
    if (!assets?.length) {
      return new Response(
        JSON.stringify({ ok: true, updated: 0, message: "Portföyde TEFAS/BEFAS varlığı yok" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    // Tekrar edenleri kaldır
    const seen = new Set<string>();
    const unique: { api_id: string; api_source: string }[] = [];
    for (const a of assets) {
      const key = `${a.api_source}:${a.api_id}`;
      if (!seen.has(key)) { seen.add(key); unique.push(a); }
    }

    const upserts: {
      symbol: string;
      api_source: string;
      price: number;
      price_currency: string;
      updated_at: string;
    }[] = [];

    for (const { api_id, api_source } of unique) {
      const price = await fetchFundPrice(api_id);
      if (price !== null) {
        upserts.push({
          symbol: api_id,
          api_source,
          price,
          price_currency: "TRY",
          updated_at: new Date().toISOString(),
        });
        console.log(`${api_id}: ${price}`);
      } else {
        console.warn(`${api_id}: fiyat alınamadı`);
      }
      // Rate limit koruması
      await new Promise((r) => setTimeout(r, 200));
    }

    if (upserts.length) {
      const { error: e } = await supabase
        .from("prices")
        .upsert(upserts, { onConflict: "symbol,api_source" });
      if (e) throw e;
    }

    return new Response(
      JSON.stringify({ ok: true, updated: upserts.length, total: unique.length }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("update-tefas hata:", err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
