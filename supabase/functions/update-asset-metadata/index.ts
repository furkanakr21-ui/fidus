import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const COINGECKO_API_KEY = Deno.env.get("COINGECKO_API_KEY") ?? "";

// ─────────────────────────────────────────────────────────────
// Yardımcılar
// ─────────────────────────────────────────────────────────────

async function upsertBatch(rows: Record<string, unknown>[]): Promise<number> {
  if (!rows.length) return 0;
  const { error } = await supabase
    .from("asset_metadata")
    .upsert(rows, { onConflict: "api_id,api_source" });
  if (error) console.warn("upsert hata:", error.message);
  return error ? 0 : rows.length;
}

// ─────────────────────────────────────────────────────────────
// BIST — Bigpara API (644 hisse, ücretsiz, güncel)
// ─────────────────────────────────────────────────────────────

async function updateBistMetadata(): Promise<number> {
  try {
    const res = await fetch("https://bigpara.hurriyet.com.tr/api/v1/hisse/list", {
      headers: { "User-Agent": "Mozilla/5.0" },
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) {
      console.warn(`Bigpara HTTP ${res.status}`);
      return 0;
    }

    const json = await res.json() as { code: number; data: { kod: string; ad: string; tip: string }[] };
    const stocks = json?.data ?? [];

    if (!stocks.length) {
      console.warn("Bigpara: boş liste");
      return 0;
    }

    const rows = stocks
      .filter((s) => s.kod && s.tip === "Hisse")
      .map((s) => ({
        symbol: s.kod.trim(),
        name: s.ad?.trim() || s.kod.trim(),
        api_source: "yahoo",
        api_id: `${s.kod.trim()}.IS`,
        asset_type: "stock",
        market: "bist",
        currency: "TRY",
        updated_at: new Date().toISOString(),
      }));

    let total = 0;
    for (let i = 0; i < rows.length; i += 500) {
      total += await upsertBatch(rows.slice(i, i + 500));
    }
    console.log(`BIST güncellendi: ${total}`);
    return total;
  } catch (e) {
    console.warn("BIST hata:", e);
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────
// ABD — NASDAQ resmi sembol dizini (nasdaqlisted + otherlisted)
// Pipe-delimited, ücretsiz, resmi kaynak: nasdaqtrader.com
// ─────────────────────────────────────────────────────────────

function isValidUsSymbol(sym: string): boolean {
  // Sadece A-Z harflerinden oluşan 1-5 karakter semboller
  // ETF ve hisseler için geçerli format
  return /^[A-Z]{1,5}$/.test(sym);
}

async function fetchNasdaqFile(
  url: string,
  symbolCol: number,
  nameCol: number,
  etfCol: number,
  testIssueCol: number,
): Promise<{ symbol: string; name: string; isEtf: boolean }[]> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0" },
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) {
      console.warn(`NASDAQ file ${url} HTTP ${res.status}`);
      return [];
    }

    const text = await res.text();
    const lines = text.trim().split("\n");
    const results: { symbol: string; name: string; isEtf: boolean }[] = [];

    for (let i = 1; i < lines.length; i++) {
      const parts = lines[i].split("|");
      if (parts.length < 4) continue;

      const symbol = parts[symbolCol]?.trim() ?? "";
      const name = parts[nameCol]?.trim() ?? "";
      const isEtf = (parts[etfCol]?.trim() ?? "") === "Y";
      const isTest = (parts[testIssueCol]?.trim() ?? "") === "Y";

      if (isTest) continue;
      if (!isValidUsSymbol(symbol)) continue;
      // Son satır genellikle metadata içerir ("File Creation Time" vb.), atla
      if (symbol.startsWith("File")) continue;

      results.push({ symbol, name: name || symbol, isEtf });
    }

    return results;
  } catch (e) {
    console.warn(`NASDAQ file hata (${url}):`, e);
    return [];
  }
}

async function updateUsMetadata(): Promise<number> {
  // nasdaqlisted.txt: Symbol|Security Name|Market Category|Test Issue|Financial Status|Round Lot Size|ETF|NextShares
  const nasdaqStocks = await fetchNasdaqFile(
    "https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt",
    0, 1, 6, 3,
  );

  // otherlisted.txt: ACT Symbol|Security Name|Exchange|CQS Symbol|ETF|Round Lot Size|Test Issue|NASDAQ Symbol
  const otherStocks = await fetchNasdaqFile(
    "https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt",
    0, 1, 4, 6,
  );

  const all = [...nasdaqStocks, ...otherStocks];
  if (!all.length) {
    console.warn("ABD: hiç sembol alınamadı");
    return 0;
  }

  // Tekrarları kaldır
  const seen = new Set<string>();
  const rows = [];
  for (const s of all) {
    if (seen.has(s.symbol)) continue;
    seen.add(s.symbol);
    rows.push({
      symbol: s.symbol,
      name: s.name,
      api_source: "yahoo",
      api_id: s.symbol,
      asset_type: s.isEtf ? "etf" : "stock",
      market: "us",
      currency: "USD",
      updated_at: new Date().toISOString(),
    });
  }

  let total = 0;
  for (let i = 0; i < rows.length; i += 500) {
    total += await upsertBatch(rows.slice(i, i + 500));
  }
  console.log(`ABD hisse+ETF güncellendi: ${total}`);
  return total;
}

// ─────────────────────────────────────────────────────────────
// Kripto — CoinGecko tüm liste (~17K+ coin)
// ─────────────────────────────────────────────────────────────

async function updateCryptoMetadata(): Promise<number> {
  const headers: Record<string, string> = {};
  if (COINGECKO_API_KEY) headers["x-cg-pro-api-key"] = COINGECKO_API_KEY;

  try {
    const res = await fetch(
      "https://api.coingecko.com/api/v3/coins/list?include_platform=false",
      { headers, signal: AbortSignal.timeout(30000) },
    );
    if (!res.ok) {
      console.warn(`CoinGecko HTTP ${res.status}`);
      return 0;
    }

    const coins = await res.json() as { id: string; symbol: string; name: string }[];
    console.log(`CoinGecko: ${coins.length} coin`);

    const rows = coins.map((c) => ({
      symbol: c.symbol.toUpperCase(),
      name: c.name,
      api_source: "coingecko",
      api_id: c.id,
      asset_type: "crypto",
      market: "crypto",
      currency: "USD",
      updated_at: new Date().toISOString(),
    }));

    let total = 0;
    for (let i = 0; i < rows.length; i += 500) {
      total += await upsertBatch(rows.slice(i, i + 500));
    }
    console.log(`Kripto güncellendi: ${total}`);
    return total;
  } catch (e) {
    console.warn("CoinGecko hata:", e);
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────
// Handler
// ─────────────────────────────────────────────────────────────

Deno.serve(async (_req) => {
  try {
    // Kripto ve BIST paralelde çalışır
    const [cryptoCount, bistCount] = await Promise.all([
      updateCryptoMetadata(),
      updateBistMetadata(),
    ]);

    // ABD sonra (büyük veri)
    const usCount = await updateUsMetadata();

    const result = { ok: true, crypto: cryptoCount, bist: bistCount, us: usCount };
    console.log("Tamamlandı:", result);
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("update-asset-metadata hata:", err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
