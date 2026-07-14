-- ============================================
-- Bookings Table Migration
-- NOTE: This app uses Firebase Auth (not Supabase Auth).
-- auth.uid() is always NULL for Flutter client requests using the anon key.
-- RLS policies use USING (true) so the anon key can read/write.
-- Row-level filtering is enforced in the app and Edge Functions.
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- BOOKINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.bookings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       TEXT NOT NULL,
  temple_id     TEXT NOT NULL,
  booking_date  DATE NOT NULL,
  booking_time  TEXT NOT NULL,          -- HH:MM format
  number_of_people INT NOT NULL DEFAULT 1 CHECK (number_of_people BETWEEN 1 AND 50),
  booking_type  TEXT NOT NULL CHECK (booking_type IN ('visit', 'event', 'special_service')),
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed', 'noShow')),
  special_requests TEXT,
  contact_name  TEXT,
  contact_phone TEXT,
  contact_email TEXT,
  amount        NUMERIC(10,2),
  currency      TEXT DEFAULT 'INR',
  payment_status TEXT DEFAULT 'pending'
                  CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
  payment_intent_id TEXT,
  transaction_id TEXT,
  metadata      JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_bookings_user_id       ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_temple_id     ON public.bookings(temple_id);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_date  ON public.bookings(booking_date);
CREATE INDEX IF NOT EXISTS idx_bookings_status        ON public.bookings(status);
-- Composite index for slot availability checks
CREATE INDEX IF NOT EXISTS idx_bookings_slot_check
  ON public.bookings(temple_id, booking_date, booking_time, status);

-- ============================================
-- BOOKING REMINDERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.booking_reminders (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id       TEXT NOT NULL,
  temple_id     TEXT NOT NULL,
  reminder_time TIMESTAMPTZ NOT NULL,
  reminder_type TEXT NOT NULL CHECK (reminder_type IN ('24_hour', '1_hour')),
  title         TEXT NOT NULL,
  message       TEXT NOT NULL,
  is_processed  BOOLEAN NOT NULL DEFAULT FALSE,
  metadata      JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_booking_reminders_booking_id
  ON public.booking_reminders(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_reminders_user_id
  ON public.booking_reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_booking_reminders_pending
  ON public.booking_reminders(is_processed, reminder_time)
  WHERE is_processed = FALSE;

-- ============================================
-- ROW LEVEL SECURITY
-- Enable RLS (safe to run even if already enabled)
-- ============================================
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_reminders ENABLE ROW LEVEL SECURITY;

-- Bookings: allow anon/authenticated to read and write
-- (Firebase UID filtering is done in queries and Edge Functions)
DROP POLICY IF EXISTS "Anon can read bookings" ON public.bookings;
CREATE POLICY "Anon can read bookings"
  ON public.bookings FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Anon can insert bookings" ON public.bookings;
CREATE POLICY "Anon can insert bookings"
  ON public.bookings FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Anon can update bookings" ON public.bookings;
CREATE POLICY "Anon can update bookings"
  ON public.bookings FOR UPDATE
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Service role full access to bookings" ON public.bookings;
CREATE POLICY "Service role full access to bookings"
  ON public.bookings FOR ALL
  USING (auth.role() = 'service_role');

-- Booking reminders: same permissive approach
DROP POLICY IF EXISTS "Anon can read booking reminders" ON public.booking_reminders;
CREATE POLICY "Anon can read booking reminders"
  ON public.booking_reminders FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Anon can insert booking reminders" ON public.booking_reminders;
CREATE POLICY "Anon can insert booking reminders"
  ON public.booking_reminders FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Anon can update booking reminders" ON public.booking_reminders;
CREATE POLICY "Anon can update booking reminders"
  ON public.booking_reminders FOR UPDATE
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Service role full access to booking reminders" ON public.booking_reminders;
CREATE POLICY "Service role full access to booking reminders"
  ON public.booking_reminders FOR ALL
  USING (auth.role() = 'service_role');

-- ============================================
-- GRANTS
-- ============================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bookings TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.booking_reminders TO anon, authenticated;
GRANT ALL ON public.bookings TO service_role;
GRANT ALL ON public.booking_reminders TO service_role;

-- ============================================
-- REALTIME
-- Enable realtime so watchUserBookings() stream works
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;
END $$;

-- ============================================
-- AUTO-UPDATE updated_at
-- ============================================
CREATE OR REPLACE FUNCTION public.update_bookings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bookings_updated_at ON public.bookings;
CREATE TRIGGER trg_bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.update_bookings_updated_at();
