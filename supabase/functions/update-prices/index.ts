import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const COINGECKO_API_KEY = Deno.env.get("COINGECKO_API_KEY") ?? "";
const EXCHANGERATE_API_KEY = Deno.env.get("EXCHANGERATE_API_KEY") ?? "";
const YAHOO_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

// ─────────────────────────────────────────────────────────────
// 1. Döviz Kurları
// ─────────────────────────────────────────────────────────────

async function updateExchangeRates(): Promise<Map<string, number>> {
  const { data: latest } = await supabase
    .from("exchange_rates")
    .select("currency,rate_per_usd,updated_at")
    .limit(1)
    .maybeSingle();

  if (latest?.updated_at) {
    const ageMs = Date.now() - new Date(latest.updated_at).getTime();
    if (ageMs < 30 * 60 * 1000) {
      const { data: all } = await supabase.from("exchange_rates").select("currency,rate_per_usd");
      const map = new Map<string, number>();
      for (const r of (all ?? [])) map.set(r.currency, r.rate_per_usd);
      return map;
    }
  }

  let rates: Record<string, number> = {};

  if (EXCHANGERATE_API_KEY) {
    try {
      const res = await fetch(
        `https://v6.exchangerate-api.com/v6/${EXCHANGERATE_API_KEY}/latest/USD`,
        { signal: AbortSignal.timeout(15000) },
      );
      const json = await res.json();
      if (json.result === "success" && json.conversion_rates) {
        rates = json.conversion_rates;
        console.log("ExchangeRate-API kullanıldı");
      }
    } catch (e) {
      console.warn("ExchangeRate-API hata:", e);
    }
  }

  if (Object.keys(rates).length === 0) {
    try {
      const res = await fetch("https://open.er-api.com/v6/latest/USD", {
        signal: AbortSignal.timeout(15000),
      });
      const json = await res.json();
      if (json.result === "success" && json.rates) {
        rates = json.rates;
        console.log("open.er-api.com fallback kullanıldı");
      }
    } catch (e) {
      console.warn("open.er-api hata:", e);
    }
  }

  if (Object.keys(rates).length > 0) {
    const upserts = Object.entries(rates).map(([currency, rate]) => ({
      currency,
      rate_per_usd: rate,
      updated_at: new Date().toISOString(),
    }));
    const { error } = await supabase
      .from("exchange_rates")
      .upsert(upserts, { onConflict: "currency" });
    if (error) console.warn("exchange_rates upsert hata:", error);
    else console.log(`Döviz kurları güncellendi: ${upserts.length} para birimi`);
  }

  const map = new Map<string, number>();
  for (const [k, v] of Object.entries(rates)) map.set(k, v);
  return map;
}

// ─────────────────────────────────────────────────────────────
// 2. Yahoo Finance — chart endpoint (crumb gerektirmez)
// ─────────────────────────────────────────────────────────────

async function fetchYahooPrice(
  symbol: string,
): Promise<{ price: number; currency: string } | null> {
  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?range=1d&interval=1d`;
    const res = await fetch(url, {
      headers: { "User-Agent": YAHOO_UA, "Accept": "application/json" },
      signal: AbortSignal.timeout(12000),
    });
    if (!res.ok) {
      // query2 ile dene
      const url2 = `https://query2.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?range=1d&interval=1d`;
      const res2 = await fetch(url2, {
        headers: { "User-Agent": YAHOO_UA, "Accept": "application/json" },
        signal: AbortSignal.timeout(12000),
      });
      if (!res2.ok) return null;
      const d2 = await res2.json();
      return extractYahooChartPrice(d2);
    }
    const data = await res.json();
    return extractYahooChartPrice(data);
  } catch {
    return null;
  }
}

function extractYahooChartPrice(
  data: unknown,
): { price: number; currency: string } | null {
  try {
    const d = data as Record<string, unknown>;
    const chart = d?.chart as Record<string, unknown[]> | undefined;
    const result = chart?.result?.[0] as Record<string, unknown> | undefined;
    if (!result) return null;
    const m = result.meta as Record<string, unknown> | undefined;
    if (!m) return null;
    const price = (m.regularMarketPrice ?? m.previousClose) as number | undefined;
    const currency = (m.currency as string | undefined) ?? "USD";
    if (!price || price <= 0) return null;
    return { price, currency };
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// 3. CoinGecko — kripto TRY cinsinden
// ─────────────────────────────────────────────────────────────

async function updateCryptoPrices() {
  const { data: assets, error } = await supabase
    .from("assets")
    .select("api_id")
    .eq("api_source", "coingecko");

  if (error) throw error;
  if (!assets?.length) return;

  const ids = [...new Set(assets.map((a: { api_id: string }) => a.api_id))].filter(Boolean);
  if (!ids.length) return;

  const headers: Record<string, string> = {};
  if (COINGECKO_API_KEY) headers["x-cg-pro-api-key"] = COINGECKO_API_KEY;

  const chunkSize = 250;
  for (let i = 0; i < ids.length; i += chunkSize) {
    const chunk = ids.slice(i, i + chunkSize).join(",");
    try {
      const res = await fetch(
        `https://api.coingecko.com/api/v3/simple/price?ids=${chunk}&vs_currencies=usd`,
        { headers, signal: AbortSignal.timeout(15000) },
      );
      if (!res.ok) { console.warn(`CoinGecko HTTP ${res.status}`); continue; }
      const data = await res.json();

      const upserts = Object.entries(data).map(([id, prices]: [string, unknown]) => ({
        symbol: id,
        api_source: "coingecko",
        price: (prices as Record<string, number>)["usd"],
        price_currency: "USD",
        updated_at: new Date().toISOString(),
      }));

      if (upserts.length) {
        const { error: e } = await supabase
          .from("prices")
          .upsert(upserts, { onConflict: "symbol,api_source" });
        if (e) console.warn("CoinGecko upsert hata:", e);
        else console.log(`Kripto güncellendi: ${upserts.length}`);
      }
    } catch (e) {
      console.warn("CoinGecko hata:", e);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 4. Yahoo Finance — BIST + yabancı hisse/ETF
// ─────────────────────────────────────────────────────────────

async function updateYahooPrices(rates: Map<string, number>) {
  const { data: assets, error } = await supabase
    .from("assets")
    .select("api_id")
    .eq("api_source", "yahoo");

  if (error) throw error;
  if (!assets?.length) return;

  const symbols = [...new Set(assets.map((a: { api_id: string }) => a.api_id))].filter(Boolean);
  if (!symbols.length) return;

  const upserts: {
    symbol: string; api_source: string; price: number;
    price_currency: string; updated_at: string;
  }[] = [];

  for (const sym of symbols) {
    const result = await fetchYahooPrice(sym);
    if (!result) { console.warn(`${sym}: fiyat alınamadı`); continue; }

    // Fiyatı orijinal para biriminde sakla — uygulama kur dönüşümünü yapar
    const currency = result.currency.toUpperCase();
    const priceCurrency = (currency === "TRY" || currency === "USD") ? currency : "USD";
    let price = result.price;

    // TRY ve USD dışı para birimi → USD'ye çevir
    if (currency !== "TRY" && currency !== "USD") {
      const rate = rates.get(currency) ?? 0;
      price = rate > 0 ? result.price / rate : 0;
    }

    if (price > 0) {
      upserts.push({
        symbol: sym,
        api_source: "yahoo",
        price,
        price_currency: priceCurrency,
        updated_at: new Date().toISOString(),
      });
      console.log(`${sym}: ${price.toFixed(4)} ${priceCurrency}`);
    }
    await new Promise((r) => setTimeout(r, 150));
  }

  if (upserts.length) {
    const { error: e } = await supabase
      .from("prices")
      .upsert(upserts, { onConflict: "symbol,api_source" });
    if (e) throw e;
    console.log(`Yahoo güncellendi: ${upserts.length}`);
  }
}

// ─────────────────────────────────────────────────────────────
// 5. Döviz varlıkları — prices tablosuna TRY fiyat yaz
// ─────────────────────────────────────────────────────────────

async function updateCurrencyPrices(rates: Map<string, number>) {
  const usdToTry = rates.get("TRY") ?? 0;
  if (usdToTry <= 0) return;

  const { data: assets, error } = await supabase
    .from("assets")
    .select("api_id")
    .eq("api_source", "exchangerate");

  if (error || !assets?.length) return;

  const ids = [...new Set(assets.map((a: { api_id: string }) => a.api_id))].filter(Boolean);
  const upserts: {
    symbol: string; api_source: string; price: number;
    price_currency: string; updated_at: string;
  }[] = [];

  for (const id of ids) {
    const rate = rates.get(id) ?? 0;
    if (rate <= 0) continue;
    // 1 birim = kaç TRY: 1/rate_per_usd * usdToTry
    const priceTry = (1 / rate) * usdToTry;
    upserts.push({
      symbol: id,
      api_source: "exchangerate",
      price: priceTry,
      price_currency: "TRY",
      updated_at: new Date().toISOString(),
    });
    console.log(`${id}: ${priceTry.toFixed(4)} TRY`);
  }

  if (upserts.length) {
    const { error: e } = await supabase
      .from("prices")
      .upsert(upserts, { onConflict: "symbol,api_source" });
    if (e) console.warn("Döviz prices upsert hata:", e);
    else console.log(`Döviz fiyatları güncellendi: ${upserts.length}`);
  }
}

// ─────────────────────────────────────────────────────────────
// 6. Emtia — altın/gümüş/platin Yahoo Finance futures
// ─────────────────────────────────────────────────────────────

// apiId → Yahoo ticker.
// gramsPerUnit tanımlı  → TRY cinsinden gram/sikke fiyatı (Flutter'da currency='TRY')
// gramsPerUnit tanımsız → USD cinsinden ons fiyatı      (Flutter'da currency='USD')
const COMMODITY_MAP: Record<string, { yahooTicker: string; gramsPerUnit?: number }> = {
  // TRY gram/sikke fiyatları
  "XAU_GRAM":   { yahooTicker: "GC=F", gramsPerUnit: 1 },
  "XAU_CEYREK": { yahooTicker: "GC=F", gramsPerUnit: 1.75 },
  "XAU_YARIM":  { yahooTicker: "GC=F", gramsPerUnit: 3.5 },
  "XAU_TAM":    { yahooTicker: "GC=F", gramsPerUnit: 7.0 },
  "XAG_GRAM":   { yahooTicker: "SI=F", gramsPerUnit: 1 },
  "XPT_GRAM":   { yahooTicker: "PL=F", gramsPerUnit: 1 },
  "XPD_GRAM":   { yahooTicker: "PA=F", gramsPerUnit: 1 },
  // USD ons fiyatları
  "XAU": { yahooTicker: "GC=F" },
  "XAG": { yahooTicker: "SI=F" },
  "XPT": { yahooTicker: "PL=F" },
  "XPD": { yahooTicker: "PA=F" },
};

async function updateCommodityPrices(rates: Map<string, number>) {
  const usdToTry = rates.get("TRY") ?? 0;
  if (usdToTry <= 0) return;

  const { data: assets, error } = await supabase
    .from("assets")
    .select("api_id")
    .eq("api_source", "goldapi");

  if (error || !assets?.length) return;

  const ids = [...new Set(assets.map((a: { api_id: string }) => a.api_id))].filter(Boolean);

  // Gereken Yahoo ticker'ları tek seferde çek
  const tickerCache = new Map<string, number>(); // yahooTicker → USD per ounce
  const uniqueTickers = [...new Set(ids.map((id) => COMMODITY_MAP[id]?.yahooTicker).filter(Boolean))];

  for (const ticker of uniqueTickers) {
    const result = await fetchYahooPrice(ticker!);
    if (result) {
      const usdPrice = result.currency.toUpperCase() === "USD"
        ? result.price
        : result.price / (rates.get(result.currency.toUpperCase()) ?? 1);
      tickerCache.set(ticker!, usdPrice);
      console.log(`${ticker}: ${usdPrice} USD/ons`);
    }
    await new Promise((r) => setTimeout(r, 150));
  }

  const upserts: {
    symbol: string; api_source: string; price: number;
    price_currency: string; updated_at: string;
  }[] = [];

  const TROY_OZ_TO_GRAM = 31.1035;

  for (const id of ids) {
    const mapping = COMMODITY_MAP[id];
    if (!mapping) continue;

    const ouncePriceUsd = tickerCache.get(mapping.yahooTicker) ?? 0;
    if (ouncePriceUsd <= 0) continue;

    if (mapping.gramsPerUnit !== undefined) {
      // TRY gram/sikke fiyatı — Flutter'da currency='TRY', currentValue direkt kullanır
      const gramPriceTry = (ouncePriceUsd / TROY_OZ_TO_GRAM) * usdToTry;
      const price = gramPriceTry * mapping.gramsPerUnit;
      if (price > 0) {
        upserts.push({
          symbol: id,
          api_source: "goldapi",
          price,
          price_currency: "TRY",
          updated_at: new Date().toISOString(),
        });
        console.log(`${id}: ${price.toFixed(2)} TRY`);
      }
    } else {
      // USD ons fiyatı — Flutter'da currency='USD', currentValue usdToTry ile çarpar
      upserts.push({
        symbol: id,
        api_source: "goldapi",
        price: ouncePriceUsd,
        price_currency: "USD",
        updated_at: new Date().toISOString(),
      });
      console.log(`${id}: ${ouncePriceUsd.toFixed(4)} USD`);
    }
  }

  if (upserts.length) {
    const { error: e } = await supabase
      .from("prices")
      .upsert(upserts, { onConflict: "symbol,api_source" });
    if (e) console.warn("Emtia upsert hata:", e);
    else console.log(`Emtia fiyatları güncellendi: ${upserts.length}`);
  }
}

// ─────────────────────────────────────────────────────────────
// Ana handler
// ─────────────────────────────────────────────────────────────

Deno.serve(async (_req) => {
  try {
    const rates = await updateExchangeRates();

    await Promise.all([
      updateCryptoPrices(),
      updateYahooPrices(rates),
      updateCurrencyPrices(rates),
      updateCommodityPrices(rates),
    ]);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("update-prices hata:", err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
