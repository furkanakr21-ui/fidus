import unittest

import tefas_ingest


def fund_row(code, *, is_befas=False, price=None):
    return {
        "code": code,
        "is_befas": is_befas,
        "name": f"{code} Fund",
        "type": "Test",
        "category": "Test",
        "source_fon_tipi": "EMK" if is_befas else "YAT",
        "fund_family_label": "Test",
        "price": price,
        "price_date": "2026-05-28" if price else None,
        "share_count": None,
        "investor_count": None,
        "exchange_bulletin_price": None,
        "total_size": None,
        "return_1w": None,
        "return_1m": None,
        "return_3m": None,
        "return_6m": None,
        "return_1y": None,
        "return_ytd": None,
        "return_3y": None,
        "return_5y": None,
        "risk_level": None,
        "last_seen_at": "2026-05-28T00:00:00+00:00",
        "is_active": True,
        "updated_at": "2026-05-28T00:00:00+00:00",
    }


class FakeDb:
    def __init__(self):
        self.upserts = []
        self.patches = []

    def upsert(self, table, rows, on_conflict, batch_size=200):
        self.upserts.append((table, rows, on_conflict))

    def patch(self, table, params, values):
        self.patches.append((table, params, values))


class TefasIngestBehaviorTest(unittest.TestCase):
    def test_validate_rows_accepts_partial_family_updates(self):
        rows_by_family = {
            "GYF": [fund_row("GY1", price=1.23)],
            "GSYF": [fund_row("GS1")],
        }

        tefas_ingest.validate_rows(rows_by_family)

    def test_validate_rows_rejects_empty_runs(self):
        with self.assertRaisesRegex(RuntimeError, "No fund rows"):
            tefas_ingest.validate_rows({"GYF": [], "GSYF": []})

    def test_validate_rows_accepts_rows_without_positive_prices(self):
        rows_by_family = {
            "GSYF": [fund_row("GS1")],
        }

        tefas_ingest.validate_rows(rows_by_family)

    def test_publish_does_not_deactivate_missing_or_clear_empty_prices(self):
        db = FakeDb()
        rows = [
            fund_row("AAA", price=10.5),
            fund_row("BBB", price=None),
        ]

        tefas_ingest.publish(db, rows, "2026-05-28T00:00:00+00:00")

        self.assertEqual(db.patches, [])
        fund_upserts = [entry for entry in db.upserts if entry[0] == "tefas_funds"]
        price_upserts = [entry for entry in db.upserts if entry[0] == "prices"]

        self.assertEqual(len(price_upserts), 1)
        self.assertEqual(price_upserts[0][1], [
            {
                "symbol": "AAA",
                "api_source": "tefas",
                "price": 10.5,
                "price_currency": "TRY",
                "updated_at": "2026-05-28T00:00:00+00:00",
            }
        ])

        no_price_payloads = [
            row
            for _, rows_payload, _ in fund_upserts
            for row in rows_payload
            if row["code"] == "BBB"
        ]
        self.assertEqual(len(no_price_payloads), 1)
        self.assertNotIn("price", no_price_payloads[0])
        self.assertNotIn("price_date", no_price_payloads[0])


if __name__ == "__main__":
    unittest.main()
