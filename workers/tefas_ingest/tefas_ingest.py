from __future__ import annotations

import json
import os
import sys
import time
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from typing import Any
from zoneinfo import ZoneInfo

from curl_cffi import requests


BASE = "https://www.tefas.gov.tr"
GENERAL_ENDPOINT = f"{BASE}/api/funds/fonGnlBlgSiraliGetir"
RETURNS_ENDPOINT = f"{BASE}/api/funds/fonGetiriBazliBilgiGetir"
CHROME_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/131.0.0.0 Safari/537.36"
)


@dataclass(frozen=True)
class FundFamily:
    code: str
    label: str
    is_befas: bool
    portal_path: str
    fund_type_param: str | None
    min_count: int
    min_price_ratio: float
    sentinels: tuple[str, ...]

    @property
    def api_source(self) -> str:
        return "befas" if self.is_befas else "tefas"


FAMILIES: tuple[FundFamily, ...] = (
    FundFamily("YAT", "Yatirim Fonu", False, "/tr/fon-verileri", "YAT", 1500, 0.90, ("AAL", "IPB")),
    FundFamily("EMK", "Emeklilik Fonu", True, "/tr/fon-verileri", "EMK", 300, 0.90, ("AAJ", "ABE")),
    FundFamily("BYF", "Borsa Yatirim Fonu", False, "/tr/fon-verileri", "BYF", 20, 0.90, ("BLH", "BOE")),
    FundFamily("GYF", "Gayrimenkul Fonu", False, "/tr/gayrimenkul-fonlari", None, 180, 0.85, ("AB1", "ABZ")),
    FundFamily("GSYF", "Girisim Sermayesi Fonu", False, "/tr/girisim-sermayesi-fonlari", None, 350, 0.85, ("ABH", "AGN")),
)


def env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def env_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError:
        return default


def parse_num(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        text = value.strip().replace(",", ".")
        if not text:
            return None
        try:
            return float(text)
        except ValueError:
            return None
    return None


def parse_positive(value: Any) -> float | None:
    num = parse_num(value)
    return num if num is not None and num > 0 else None


def parse_int(value: Any) -> int | None:
    num = parse_num(value)
    return int(num) if num is not None else None


def parse_price_date(value: Any) -> str | None:
    if not value:
        return None
    text = str(value).strip()
    for fmt in ("%Y-%m-%d", "%Y%m%d", "%d.%m.%Y"):
        try:
            return datetime.strptime(text[:10], fmt).date().isoformat()
        except ValueError:
            pass
    return None


class RateLimiter:
    def __init__(self, interval_s: float) -> None:
        self.interval_s = interval_s
        self.last_request_at = 0.0
        self.request_count = 0
        self.retry_count = 0

    def wait(self) -> None:
        elapsed = time.monotonic() - self.last_request_at
        wait_s = self.interval_s - elapsed
        if wait_s > 0:
            time.sleep(wait_s)
        self.last_request_at = time.monotonic()
        self.request_count += 1

    def mark_retry(self) -> None:
        self.retry_count += 1


class TefasClient:
    def __init__(
        self,
        interval_s: float,
        max_retries: int,
        page_size: int,
        max_pages: int | None,
    ) -> None:
        self.limiter = RateLimiter(interval_s)
        self.max_retries = max_retries
        self.page_size = page_size
        self.max_pages = max_pages

    def new_session(self, family: FundFamily, target: date) -> requests.Session:
        session = requests.Session(impersonate="chrome131")
        session.headers.update(
            {
                "User-Agent": CHROME_UA,
                "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.8",
            }
        )
        self.request(session, "GET", f"{BASE}/tr/", expect_json=False)
        self.request(
            session,
            "GET",
            f"{BASE}/tr/FonAnaliz/FonKarsilastirma.aspx",
            expect_json=False,
            referer=f"{BASE}/tr/",
        )
        portal_url = self.portal_url(family, target)
        self.request(session, "GET", portal_url, expect_json=False, referer=f"{BASE}/tr/")
        return session

    def portal_url(self, family: FundFamily, target: date) -> str:
        start = target.isoformat()
        if family.fund_type_param:
            return f"{BASE}{family.portal_path}?fundType={family.fund_type_param}&startDate={start}&endDate={start}"
        return f"{BASE}{family.portal_path}?startDate={start}&endDate={start}"

    def request(
        self,
        session: requests.Session,
        method: str,
        url: str,
        *,
        json_body: dict[str, Any] | None = None,
        expect_json: bool = True,
        referer: str | None = None,
    ) -> Any:
        headers = {
            "Accept": "application/json, text/plain, */*" if expect_json else "text/html,application/xhtml+xml,*/*;q=0.8",
            "Origin": BASE,
        }
        if referer:
            headers["Referer"] = referer
        if json_body is not None:
            headers["Content-Type"] = "application/json; charset=utf-8"

        last_error = ""
        for attempt in range(self.max_retries):
            self.limiter.wait()
            try:
                response = session.request(
                    method,
                    url,
                    json=json_body,
                    headers=headers,
                    timeout=35,
                )
            except Exception as exc:  # noqa: BLE001 - surfaced in run report
                last_error = f"{type(exc).__name__}: {exc}"
                self.sleep_for_retry(attempt, None)
                continue

            text = response.text.strip()
            if response.status_code == 429:
                last_error = f"HTTP 429: {url}"
                self.sleep_for_retry(attempt, response.headers.get("retry-after"))
                continue
            if response.status_code >= 500 or response.status_code in (403, 408):
                last_error = f"HTTP {response.status_code}: {url}"
                self.sleep_for_retry(attempt, response.headers.get("retry-after"))
                continue
            if not response.ok:
                raise RuntimeError(f"HTTP {response.status_code}: {url}")
            if not expect_json:
                return text
            if not text:
                last_error = f"empty 200 response: {url}"
                self.sleep_for_retry(attempt, None)
                continue
            if text.startswith("<"):
                last_error = f"html response instead of json: {url}"
                self.sleep_for_retry(attempt, None)
                continue
            try:
                return response.json()
            except Exception as exc:  # noqa: BLE001
                last_error = f"invalid json: {type(exc).__name__}"
                self.sleep_for_retry(attempt, None)

        raise RuntimeError(last_error or f"request failed: {url}")

    def sleep_for_retry(self, attempt: int, retry_after: str | None) -> None:
        self.limiter.mark_retry()
        wait_s: float | None = None
        if retry_after:
            try:
                wait_s = float(retry_after)
            except ValueError:
                try:
                    parsed = parsedate_to_datetime(retry_after)
                    wait_s = max(0.0, (parsed - datetime.now(timezone.utc)).total_seconds())
                except Exception:
                    wait_s = None
        if wait_s is None:
            wait_s = min(60.0, (2**attempt) * 5.0)
        time.sleep(wait_s)

    def fetch_general(self, family: FundFamily, target: date) -> list[dict[str, Any]]:
        session = self.new_session(family, target)
        rows: list[dict[str, Any]] = []
        start_rank = 1
        page = 1
        total_pages = 1
        referer = self.portal_url(family, target)
        while page <= total_pages:
            if self.max_pages is not None and page > self.max_pages:
                break
            payload = {
                "fonTipi": family.code,
                "fonKodu": None,
                "aramaMetni": None,
                "fonTurKod": None,
                "fonGrubu": None,
                "sfonTurKod": None,
                "basTarih": target.strftime("%Y%m%d"),
                "bitTarih": target.strftime("%Y%m%d"),
                "basSira": start_rank,
                "bitSira": start_rank + self.page_size - 1,
                "fonTurAciklama": None,
                "dil": "TR",
                "kurucuKod": None,
            }
            body = self.request(
                session,
                "POST",
                GENERAL_ENDPOINT,
                json_body=payload,
                referer=referer,
            )
            if body.get("errorCode") or body.get("errorMessage"):
                raise RuntimeError(f"{family.code} general error: {body.get('errorMessage')}")
            page_rows = extract_rows(body)
            rows.extend(page_rows)
            total_pages = int(body.get("toplamSayfa") or body.get("totalPages") or 1)
            if not page_rows or len(page_rows) < self.page_size:
                break
            start_rank += self.page_size
            page += 1
        return rows

    def fetch_returns(self, family: FundFamily, target: date) -> list[dict[str, Any]]:
        session = self.new_session(family, target)
        body = self.request(
            session,
            "POST",
            RETURNS_ENDPOINT,
            json_body={
                "dil": "TR",
                "fonTipi": family.code,
                "kurucuKodu": None,
                "sfonTurKod": None,
                "fonTurAciklama": None,
                "islem": 1,
                "fonTurKod": None,
                "fonGrubu": None,
                "donemGetiri1a": "1",
                "donemGetiri3a": "1",
                "donemGetiri6a": "1",
                "donemGetiri1y": "1",
                "donemGetiriyb": "1",
                "donemGetiri3y": "1",
                "donemGetiri5y": "1",
                "basTarih": None,
                "bitTarih": None,
                "calismaTipi": 2,
                "getiriOrani": "1",
            },
            referer=self.portal_url(family, target),
        )
        if body.get("errorCode") or body.get("errorMessage"):
            raise RuntimeError(f"{family.code} returns error: {body.get('errorMessage')}")
        return extract_rows(body)


def extract_rows(body: Any) -> list[dict[str, Any]]:
    if isinstance(body, list):
        return [r for r in body if isinstance(r, dict)]
    if not isinstance(body, dict):
        return []
    for key in ("resultList", "data", "Data", "result", "Result", "rows", "items"):
        rows = body.get(key)
        if isinstance(rows, list):
            return [r for r in rows if isinstance(r, dict)]
    return []


def row_code(row: dict[str, Any]) -> str:
    return str(row.get("fonKodu") or row.get("fonKod") or row.get("fundCode") or "").strip().upper()


def normalize_family_rows(
    family: FundFamily,
    general_rows: list[dict[str, Any]],
    return_rows: list[dict[str, Any]],
    now_iso: str,
) -> tuple[list[dict[str, Any]], dict[str, int]]:
    returns_by_code = {row_code(row): row for row in return_rows if row_code(row)}
    normalized: list[dict[str, Any]] = []
    zero_count = 0
    null_price_count = 0

    for row in general_rows:
        code = row_code(row)
        if not code:
            continue
        ret = returns_by_code.get(code, {})
        price = parse_positive(row.get("fiyat") or row.get("price"))
        if price is None:
            if parse_num(row.get("fiyat") or row.get("price")) == 0:
                zero_count += 1
            else:
                null_price_count += 1
        category = str(ret.get("fonTurAciklama") or "").strip() or family.label
        normalized.append(
            {
                "code": code,
                "is_befas": family.is_befas,
                "name": str(row.get("fonUnvan") or ret.get("fonUnvan") or "").strip(),
                "type": category,
                "category": category,
                "source_fon_tipi": family.code,
                "fund_family_label": family.label,
                "price": price,
                "price_date": parse_price_date(row.get("tarih")),
                "share_count": parse_num(row.get("tedPaySayisi")),
                "investor_count": parse_int(row.get("kisiSayisi")),
                "exchange_bulletin_price": parse_positive(row.get("borsaBultenFiyat")),
                "total_size": parse_num(row.get("portfoyBuyukluk")),
                "return_1w": None,
                "return_1m": parse_num(ret.get("getiri1a")),
                "return_3m": parse_num(ret.get("getiri3a")),
                "return_6m": parse_num(ret.get("getiri6a")),
                "return_1y": parse_num(ret.get("getiri1y")),
                "return_ytd": parse_num(ret.get("getiriyb")),
                "return_3y": parse_num(ret.get("getiri3y")),
                "return_5y": parse_num(ret.get("getiri5y")),
                "risk_level": parse_int(ret.get("riskDegeri")),
                "last_seen_at": now_iso,
                "is_active": True,
                "updated_at": now_iso,
            }
        )
    return normalized, {"zero": zero_count, "null": null_price_count}


def validate_rows(rows_by_family: dict[str, list[dict[str, Any]]]) -> None:
    errors: list[str] = []
    tefas_codes: dict[str, str] = {}
    befas_codes: dict[str, str] = {}
    total_rows = sum(len(rows) for rows in rows_by_family.values())

    if total_rows == 0:
        raise RuntimeError("No fund rows returned from TEFAS")

    families_by_code = {family.code: family for family in FAMILIES}
    for family_code, rows in rows_by_family.items():
        family = families_by_code.get(family_code)
        if family is None:
            errors.append(f"unknown family: {family_code}")
            continue
        codes = {row["code"] for row in rows}

        bucket = befas_codes if family.is_befas else tefas_codes
        for code in codes:
            previous = bucket.get(code)
            if previous and previous != family.code:
                errors.append(f"duplicate code in {'BEFAS' if family.is_befas else 'TEFAS'} bucket: {code} in {previous},{family.code}")
            bucket[code] = family.code

    if errors:
        raise RuntimeError("; ".join(errors))


def selected_families() -> tuple[FundFamily, ...]:
    raw = os.getenv("TEFAS_FAMILIES", "").strip()
    if not raw:
        return FAMILIES
    wanted = {part.strip().upper() for part in raw.split(",") if part.strip()}
    selected = tuple(family for family in FAMILIES if family.code in wanted)
    if not selected:
        raise RuntimeError(f"TEFAS_FAMILIES did not match any known family: {raw}")
    return selected


class SupabaseRest:
    def __init__(self) -> None:
        self.url = os.environ["SUPABASE_URL"].rstrip("/")
        self.key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
        self.session = requests.Session()

    def request_with_retry(
        self,
        method: str,
        endpoint: str,
        *,
        headers: dict[str, str],
        params: dict[str, str] | None = None,
        data: str | None = None,
        timeout: int = 40,
    ) -> requests.Response:
        last_error = ""
        for attempt in range(5):
            try:
                response = self.session.request(
                    method,
                    endpoint,
                    params=params,
                    headers=headers,
                    data=data,
                    timeout=timeout,
                )
            except Exception as exc:  # noqa: BLE001
                last_error = f"{type(exc).__name__}: {exc}"
                time.sleep(min(60.0, (2**attempt) * 3.0))
                continue
            if response.status_code in (408, 429) or response.status_code >= 500:
                last_error = f"HTTP {response.status_code}: {response.text[:300]}"
                time.sleep(min(60.0, (2**attempt) * 3.0))
                continue
            return response
        raise RuntimeError(last_error or f"Supabase request failed: {endpoint}")

    def upsert(self, table: str, rows: list[dict[str, Any]], on_conflict: str, batch_size: int = 200) -> None:
        if not rows:
            return
        endpoint = f"{self.url}/rest/v1/{table}"
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        for idx in range(0, len(rows), batch_size):
            chunk = rows[idx : idx + batch_size]
            response = self.request_with_retry(
                "POST",
                endpoint,
                params={"on_conflict": on_conflict},
                headers=headers,
                data=json.dumps(chunk, ensure_ascii=False),
                timeout=40,
            )
            if not response.ok:
                raise RuntimeError(f"Supabase upsert {table} failed: {response.status_code} {response.text[:500]}")

    def patch(self, table: str, params: dict[str, str], values: dict[str, Any]) -> None:
        endpoint = f"{self.url}/rest/v1/{table}"
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        response = self.request_with_retry(
            "PATCH",
            endpoint,
            params=params,
            headers=headers,
            data=json.dumps(values, ensure_ascii=False),
            timeout=40,
        )
        if not response.ok:
            raise RuntimeError(f"Supabase patch {table} failed: {response.status_code} {response.text[:500]}")

    def insert_run(self, row: dict[str, Any]) -> None:
        endpoint = f"{self.url}/rest/v1/market_data_runs"
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        response = self.request_with_retry(
            "POST",
            endpoint,
            headers=headers,
            data=json.dumps(row, ensure_ascii=False),
            timeout=20,
        )
        if not response.ok:
            print(f"warning: market_data_runs insert failed: {response.status_code} {response.text[:300]}", file=sys.stderr)


def discover_target_date(client: TefasClient) -> tuple[date, list[dict[str, Any]]]:
    raw_target = os.getenv("TEFAS_TARGET_DATE")
    if raw_target:
        target = datetime.strptime(raw_target, "%Y-%m-%d").date()
        return target, client.fetch_general(FAMILIES[0], target)

    today_tr = datetime.now(ZoneInfo("Europe/Istanbul")).date()
    lookback = env_int("TEFAS_LOOKBACK_DAYS", 7)
    for offset in range(lookback + 1):
        target = today_tr - timedelta(days=offset)
        try:
            rows = client.fetch_general(FAMILIES[0], target)
        except Exception as exc:  # noqa: BLE001
            print(f"{target}: YAT discovery failed: {exc}", file=sys.stderr)
            continue
        if rows:
            return target, rows
    raise RuntimeError(f"No YAT data found in last {lookback} days")


def publish(
    db: SupabaseRest,
    rows: list[dict[str, Any]],
    now_iso: str,
) -> None:
    fund_rows_with_price: list[dict[str, Any]] = []
    fund_rows_without_price: list[dict[str, Any]] = []

    for row in rows:
        if row.get("price") is not None and row["price"] > 0:
            fund_rows_with_price.append(row)
            continue
        clean_row = dict(row)
        clean_row.pop("price", None)
        clean_row.pop("price_date", None)
        fund_rows_without_price.append(clean_row)

    prices = [
        {
            "symbol": row["code"],
            "api_source": "befas" if row["is_befas"] else "tefas",
            "price": row["price"],
            "price_currency": "TRY",
            "updated_at": row["updated_at"],
        }
        for row in rows
        if row.get("price") is not None and row["price"] > 0
    ]
    db.upsert("tefas_funds", fund_rows_with_price, "code,is_befas")
    db.upsert("tefas_funds", fund_rows_without_price, "code,is_befas")
    db.upsert("prices", prices, "symbol,api_source")


def main() -> int:
    started = datetime.now(timezone.utc)
    client = TefasClient(
        interval_s=env_float("TEFAS_REQUEST_INTERVAL_SECONDS", 10.0),
        max_retries=env_int("TEFAS_MAX_RETRIES", 5),
        page_size=env_int("TEFAS_PAGE_SIZE", 250),
        max_pages=(env_int("TEFAS_MAX_PAGES", 0) or None),
    )
    dry_run = os.getenv("TEFAS_DRY_RUN", "").lower() in ("1", "true", "yes")
    skip_validation = os.getenv("TEFAS_SKIP_VALIDATION", "").lower() in ("1", "true", "yes")
    families = selected_families()
    family_counts: dict[str, int] = {}
    zero_count = 0
    null_price_count = 0
    published = False
    target: date | None = None
    error_summary: str | None = None

    try:
        target, yat_rows = discover_target_date(client)
        print(f"target_date={target.isoformat()}")
        all_rows: list[dict[str, Any]] = []
        rows_by_family: dict[str, list[dict[str, Any]]] = {}
        now_iso = datetime.now(timezone.utc).isoformat()

        for family in families:
            general_rows = yat_rows if family.code == "YAT" else client.fetch_general(family, target)
            return_rows = client.fetch_returns(family, target)
            normalized, counters = normalize_family_rows(family, general_rows, return_rows, now_iso)
            rows_by_family[family.code] = normalized
            all_rows.extend(normalized)
            family_counts[family.code] = len(normalized)
            zero_count += counters["zero"]
            null_price_count += counters["null"]
            print(f"{family.code}: {len(normalized)} funds")

        if not skip_validation:
            validate_rows(rows_by_family)
        price_count = sum(1 for row in all_rows if row.get("price") is not None and row["price"] > 0)
        if not dry_run:
            publish(SupabaseRest(), all_rows, now_iso)
            published = True
        print(f"published={published} rows={len(all_rows)} prices={price_count}")
        ok = True
    except Exception as exc:  # noqa: BLE001
        ok = False
        price_count = None
        error_summary = str(exc)
        print(f"ERROR: {error_summary}", file=sys.stderr)

    finished = datetime.now(timezone.utc)
    if "SUPABASE_URL" in os.environ and "SUPABASE_SERVICE_ROLE_KEY" in os.environ:
        try:
            SupabaseRest().insert_run(
                {
                    "source": "tefas-official",
                    "started_at": started.isoformat(),
                    "finished_at": finished.isoformat(),
                    "ok": ok,
                    "published": published,
                    "target_date": target.isoformat() if target else None,
                    "request_count": client.limiter.request_count,
                    "retry_count": client.limiter.retry_count,
                    "family_counts": family_counts,
                    "price_count": price_count,
                    "zero_count": zero_count,
                    "null_price_count": null_price_count,
                    "error_summary": error_summary,
                }
            )
        except Exception as exc:  # noqa: BLE001
            print(f"warning: run log failed: {exc}", file=sys.stderr)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
