-- ============================================================
-- FIDUS - SUPABASE DATABASE MIGRATION
-- SQL Editor'a yapıştır ve çalıştır
-- ============================================================

-- Portfolios (eski local "profil" kavramını karşılar)
CREATE TABLE portfolios (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL DEFAULT 'Ana Portföy',
  emoji       TEXT NOT NULL DEFAULT '💼',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Kullanıcı profili (sync kodu burada)
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  sync_code   TEXT UNIQUE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Kullanıcı ayarları
CREATE TABLE user_settings (
  user_id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  theme                TEXT NOT NULL DEFAULT 'system',
  currency             TEXT NOT NULL DEFAULT 'TRY',
  active_portfolio_id  UUID REFERENCES portfolios(id),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- Varlıklar (current_price YOK — prices tablosundan gelir)
CREATE TABLE assets (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id  UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  symbol        TEXT NOT NULL,
  type          TEXT NOT NULL,
  quantity      NUMERIC(20, 8) NOT NULL,
  buy_price     NUMERIC(20, 8) NOT NULL,
  buy_date      DATE NOT NULL,
  platform      TEXT,
  commission    NUMERIC(20, 8) DEFAULT 0,
  note          TEXT,
  currency      TEXT NOT NULL DEFAULT 'TRY',
  api_source    TEXT,
  api_id        TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Alım/satım geçmişi
CREATE TABLE transactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id    UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('buy', 'sell')),
  quantity    NUMERIC(20, 8) NOT NULL,
  price       NUMERIC(20, 8) NOT NULL,
  commission  NUMERIC(20, 8) DEFAULT 0,
  note        TEXT,
  symbol      TEXT NOT NULL,
  asset_name  TEXT NOT NULL,
  date        TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Para girişi/çıkışı
CREATE TABLE cashflows (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id   UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title          TEXT NOT NULL,
  amount         NUMERIC(20, 8) NOT NULL,
  currency       TEXT NOT NULL DEFAULT 'TRY',
  type           TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal')),
  rate_at_entry  NUMERIC(20, 8),
  note           TEXT,
  date           TIMESTAMPTZ NOT NULL,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Hedefler
CREATE TABLE goals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id    UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  emoji           TEXT NOT NULL DEFAULT '🎯',
  type            TEXT NOT NULL,
  target_amount   NUMERIC(20, 8) NOT NULL,
  current_amount  NUMERIC(20, 8) NOT NULL DEFAULT 0,
  target_date     DATE,
  currency        TEXT NOT NULL DEFAULT 'TRY',
  note            TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Güncel fiyatlar (SADECE Edge Function yazar)
CREATE TABLE prices (
  symbol          TEXT NOT NULL,
  api_source      TEXT NOT NULL,
  price           NUMERIC(20, 8) NOT NULL CHECK (price > 0),
  price_currency  TEXT NOT NULL DEFAULT 'TRY',
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (symbol, api_source)
);

-- Döviz kurları (USD baz)
CREATE TABLE exchange_rates (
  currency      TEXT PRIMARY KEY,
  rate_per_usd  NUMERIC(20, 8) NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE cashflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own_profile"    ON profiles      USING (auth.uid() = id);
CREATE POLICY "own_portfolios" ON portfolios    USING (auth.uid() = user_id);
CREATE POLICY "own_settings"   ON user_settings USING (auth.uid() = user_id);
CREATE POLICY "own_assets"     ON assets        USING (auth.uid() = user_id);
CREATE POLICY "own_transactions" ON transactions USING (auth.uid() = user_id);
CREATE POLICY "own_cashflows"  ON cashflows     USING (auth.uid() = user_id);
CREATE POLICY "own_goals"      ON goals         USING (auth.uid() = user_id);

-- Fiyatlar herkese readable, yazma yok (sadece service role)
CREATE POLICY "read_prices"         ON prices          FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_exchange_rates" ON exchange_rates  FOR SELECT TO authenticated USING (true);

-- ============================================================
-- REALTIME
-- ============================================================

ALTER TABLE assets         REPLICA IDENTITY FULL;
ALTER TABLE transactions   REPLICA IDENTITY FULL;
ALTER TABLE cashflows      REPLICA IDENTITY FULL;
ALTER TABLE goals          REPLICA IDENTITY FULL;
ALTER TABLE prices         REPLICA IDENTITY FULL;
ALTER TABLE exchange_rates REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE assets, transactions, cashflows, goals, prices, exchange_rates;

-- ============================================================
-- TEFAS/BEFAS Fon Listesi Cache (dış Python worker yazar)
-- ============================================================

CREATE TABLE IF NOT EXISTS tefas_funds (
  code        TEXT    NOT NULL,
  is_befas    BOOLEAN NOT NULL DEFAULT false,
  name        TEXT,
  type        TEXT,
  category    TEXT,
  price       NUMERIC(20, 8) CHECK (price IS NULL OR price > 0),
  return_1w   NUMERIC(18, 6),
  return_1m   NUMERIC(18, 6),
  return_3m   NUMERIC(18, 6),
  return_6m   NUMERIC(18, 6),
  return_1y   NUMERIC(18, 6),
  return_ytd  NUMERIC(18, 6),
  return_3y   NUMERIC(18, 6),
  return_5y   NUMERIC(18, 6),
  total_size  NUMERIC(20, 2),
  source_fon_tipi text,
  fund_family_label text,
  price_date date,
  share_count numeric(30, 8),
  investor_count bigint,
  exchange_bulletin_price numeric(20, 8),
  risk_level integer,
  last_seen_at timestamptz,
  is_active boolean not null default true,
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (code, is_befas)
);

ALTER TABLE tefas_funds ENABLE ROW LEVEL SECURITY;

-- Herkese açık okuma (piyasa verisi)
CREATE POLICY "public_read_tefas_funds" ON tefas_funds FOR SELECT USING (true);

CREATE TABLE IF NOT EXISTS market_data_runs (
  id bigserial primary key,
  source text not null,
  started_at timestamptz not null,
  finished_at timestamptz,
  ok boolean not null default false,
  published boolean not null default false,
  target_date date,
  request_count integer not null default 0,
  retry_count integer not null default 0,
  duration_s numeric generated always as (
    case
      when finished_at is null then null
      else extract(epoch from (finished_at - started_at))
    end
  ) stored,
  family_counts jsonb,
  price_count integer,
  zero_count integer not null default 0,
  null_price_count integer not null default 0,
  error_summary text,
  created_at timestamptz not null default now()
);

ALTER TABLE market_data_runs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "market_data_runs authenticated read"
  ON market_data_runs FOR SELECT TO authenticated USING (true);

-- ============================================================
-- YENI KULLANICI TRIGGER
-- Kayıt olunca otomatik profil + portföy + ayar oluşturur
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  raw_code       TEXT;
  formatted_code TEXT;
  new_portfolio  UUID;
BEGIN
  -- Email prefix → sync code (örn: abcdefghijkl@fidus.app → ABCD-EFGH-IJKL)
  raw_code := UPPER(SPLIT_PART(NEW.email, '@', 1));
  formatted_code := SUBSTRING(raw_code, 1, 4) || '-' ||
                    SUBSTRING(raw_code, 5, 4) || '-' ||
                    SUBSTRING(raw_code, 9, 4);

  INSERT INTO public.profiles (id, sync_code)
  VALUES (NEW.id, formatted_code);

  INSERT INTO public.portfolios (user_id, name, emoji)
  VALUES (NEW.id, 'Ana Portföy', '💼')
  RETURNING id INTO new_portfolio;

  INSERT INTO public.user_settings (user_id, active_portfolio_id)
  VALUES (NEW.id, new_portfolio);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
