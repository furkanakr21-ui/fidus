import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const RAPIDAPI_KEY = Deno.env.get("RAPIDAPI_KEY") ?? "";
const RAPIDAPI_BASE = "https://tefas-api.p.rapidapi.com";
const RAPIDAPI_HOST = "tefas-api.p.rapidapi.com";
const PAGE_SIZE = 200;
const MAX_PAGES = 25;

const HEADERS = {
  "x-rapidapi-key": RAPIDAPI_KEY,
  "x-rapidapi-host": RAPIDAPI_HOST,
  "Content-Type": "application/json",
};

function parseNum(v: unknown): number | null {
  if (v === null || v === undefined) return null;
  if (typeof v === "number") return isFinite(v) ? v : null;
  if (typeof v === "string") {
    const n = parseFloat(v.replace(",", "."));
    return isFinite(n) ? n : null;
  }
  return null;
}

function parseStr(v: unknown): string {
  return v != null ? String(v).trim() : "";
}

function extractList(body: unknown): Record<string, unknown>[] {
  if (Array.isArray(body)) return body as Record<string, unknown>[];
  if (body && typeof body === "object") {
    const b = body as Record<string, unknown>;
    for (const k of ["data", "funds", "result", "items", "results", "list"]) {
      if (Array.isArray(b[k])) return b[k] as Record<string, unknown>[];
    }
  }
  return [];
}

function isBefasRow(row: Record<string, unknown>): boolean {
  const ft = parseStr(row["fundType"] ?? row["fund_type"] ?? row["fonTuru"]);
  const name = parseStr(row["title"] ?? row["name"] ?? row["fund_name"] ?? row["fonAdi"]).toUpperCase();
  const type = parseStr(row["type"] ?? row["category"] ?? "").toUpperCase();
  return ft === "2" ||
    name.includes("EMEKLİLİK") ||
    name.includes(" OKS ") ||
    name.includes(" EYF") ||
    type.includes("EMEKLİLİK") ||
    type.includes("PENSION");
}

function rowToUpsert(row: Record<string, unknown>) {
  const code = parseStr(
    row["code"] ?? row["fund_code"] ?? row["fonKodu"] ?? row["FONKODU"] ??
    row["fon_kodu"] ?? row["key"] ?? row["fundCode"],
  );
  if (!code) return null;

  const name = parseStr(
    row["title"] ?? row["name"] ?? row["fund_name"] ?? row["fonAdi"] ??
    row["FonAdi"] ?? row["fon_adi"] ?? row["fundName"] ?? row["value"],
  );

  const type = parseStr(
    row["fund_type"] ?? row["type"] ?? row["fonTuru"] ?? row["kategori"] ??
    row["category"] ?? row["fundType"],
  );

  const category = parseStr(row["category"] ?? row["kategori"] ?? row["subCategory"] ?? "");

  return {
    code,
    is_befas: isBefasRow(row),
    name,
    type: type || null,
    category: category || null,
    price: parseNum(row["price"] ?? row["FIYAT"] ?? row["birimPayDegeri"]),
    return_1w: parseNum(row["return1w"] ?? row["return1Week"] ?? row["haftalik"] ?? row["getiri1h"]),
    return_1m: parseNum(row["return1m"] ?? row["return1Month"] ?? row["aylik"] ?? row["getiri1a"]),
    return_3m: parseNum(row["return3m"] ?? row["return3Month"] ?? row["ucaylik"] ?? row["getiri3a"]),
    return_6m: parseNum(row["return6m"] ?? row["return6Month"] ?? row["altiaylik"] ?? row["getiri6a"]),
    return_1y: parseNum(row["return1y"] ?? row["return1Year"] ?? row["yillik"] ?? row["getiri1y"]),
    return_ytd: parseNum(row["returnYtd"] ?? row["returnYTD"] ?? row["ytd"] ?? row["yilbasi"]),
    total_size: parseNum(row["total_size"] ?? row["totalSize"] ?? row["fonBuyuklugu"]),
    updated_at: new Date().toISOString(),
  };
}

Deno.serve(async (_req) => {
  try {
    const allRows: ReturnType<typeof rowToUpsert>[] = [];
    const seen = new Set<string>();

    for (let page = 1; page <= MAX_PAGES; page++) {
      const url = `${RAPIDAPI_BASE}/api/v1/funds/returns/${page}?size=${PAGE_SIZE}`;
      const res = await fetch(url, {
        headers: HEADERS,
        signal: AbortSignal.timeout(25000),
      });

      if (!res.ok) {
        console.warn(`Sayfa ${page} HTTP ${res.status}, duruyoruz`);
        break;
      }

      const body = await res.json();
      const list = extractList(body);

      if (list.length === 0) break;

      for (const row of list) {
        const upsert = rowToUpsert(row);
        if (!upsert) continue;
        const key = `${upsert.code}_${upsert.is_befas}`;
        if (seen.has(key)) continue;
        seen.add(key);
        allRows.push(upsert);
      }

      console.log(`Sayfa ${page}: ${list.length} fon (toplam: ${allRows.length})`);

      if (list.length < PAGE_SIZE) break;

      await new Promise((r) => setTimeout(r, 300));
    }

    if (allRows.length === 0) {
      return new Response(
        JSON.stringify({ ok: false, error: "RapidAPI boş liste döndürdü" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // Toplu upsert (500'erli batch)
    const BATCH = 500;
    for (let i = 0; i < allRows.length; i += BATCH) {
      const batch = allRows.slice(i, i + BATCH);
      const { error } = await supabase
        .from("tefas_funds")
        .upsert(batch, { onConflict: "code,is_befas" });
      if (error) throw error;
    }

    console.log(`Tamamlandı: ${allRows.length} fon güncellendi`);
    return new Response(
      JSON.stringify({ ok: true, updated: allRows.length }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("update-tefas-funds hata:", err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
