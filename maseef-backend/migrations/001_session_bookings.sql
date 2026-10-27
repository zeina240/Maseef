-- MASEEF session booking migration.
-- DO NOT RUN until the schema has been reviewed and explicitly approved.
-- This file only adds new tables. It does not DROP, TRUNCATE, or ALTER
-- the existing users, chalets, bookings, reviews, or favorites tables.
-- It does not insert listings, users, prices, or sample bookings.
--
-- The existing bookings table stays a night-range record
-- (check_out > check_in). Same-day morning, evening, and full-day
-- requests live in booking_requests so that model does not have to change.
-- Overnight sessions are not supported: every stored window ends later
-- on the same calendar date. A full-day request still blocks the whole
-- stay_date, including both sessions.

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE IF NOT EXISTS listing_booking_profiles (
    listing_key TEXT PRIMARY KEY,
    chalet_id BIGINT UNIQUE REFERENCES chalets(id) ON DELETE SET NULL,
    owner_user_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    offers_full_day BOOLEAN NOT NULL,
    offers_sessions BOOLEAN NOT NULL,
    morning_start TIME,
    morning_end TIME,
    evening_start TIME,
    evening_end TIME,
    full_day_check_in TIME,
    full_day_check_out TIME,
    morning_price NUMERIC(10, 2),
    evening_price NUMERIC(10, 2),
    full_day_price NUMERIC(10, 2),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT listing_booking_profiles_mode_selected CHECK (
        offers_full_day OR offers_sessions
    ),
    CONSTRAINT listing_booking_profiles_morning_order CHECK (
        (morning_start IS NULL AND morning_end IS NULL)
        OR (morning_start IS NOT NULL AND morning_end IS NOT NULL AND morning_start < morning_end)
    ),
    CONSTRAINT listing_booking_profiles_evening_order CHECK (
        (evening_start IS NULL AND evening_end IS NULL)
        OR (evening_start IS NOT NULL AND evening_end IS NOT NULL AND evening_start < evening_end)
    ),
    CONSTRAINT listing_booking_profiles_full_day_order CHECK (
        (full_day_check_in IS NULL AND full_day_check_out IS NULL)
        OR (
            full_day_check_in IS NOT NULL
            AND full_day_check_out IS NOT NULL
            AND full_day_check_in < full_day_check_out
        )
    ),
    CONSTRAINT listing_booking_profiles_session_times CHECK (
        NOT offers_sessions
        OR morning_start IS NOT NULL
        OR evening_start IS NOT NULL
    ),
    CONSTRAINT listing_booking_profiles_full_day_times CHECK (
        NOT offers_full_day
        OR (full_day_check_in IS NOT NULL AND full_day_check_out IS NOT NULL)
    ),
    CONSTRAINT listing_booking_profiles_sessions_do_not_overlap CHECK (
        morning_end IS NULL
        OR evening_start IS NULL
        OR morning_end <= evening_start
        OR evening_end <= morning_start
    ),
    CONSTRAINT listing_booking_profiles_prices_nonnegative CHECK (
        (morning_price IS NULL OR morning_price >= 0)
        AND (evening_price IS NULL OR evening_price >= 0)
        AND (full_day_price IS NULL OR full_day_price >= 0)
    )
);

CREATE TABLE IF NOT EXISTS listing_availability_dates (
    listing_key TEXT NOT NULL REFERENCES listing_booking_profiles(listing_key) ON DELETE CASCADE,
    stay_date DATE NOT NULL,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    offers_full_day BOOLEAN,
    offers_sessions BOOLEAN,
    morning_start TIME,
    morning_end TIME,
    evening_start TIME,
    evening_end TIME,
    full_day_check_in TIME,
    full_day_check_out TIME,
    morning_price NUMERIC(10, 2),
    evening_price NUMERIC(10, 2),
    full_day_price NUMERIC(10, 2),
    PRIMARY KEY (listing_key, stay_date),
    CONSTRAINT listing_availability_dates_morning_order CHECK (
        (morning_start IS NULL AND morning_end IS NULL)
        OR (morning_start IS NOT NULL AND morning_end IS NOT NULL AND morning_start < morning_end)
    ),
    CONSTRAINT listing_availability_dates_evening_order CHECK (
        (evening_start IS NULL AND evening_end IS NULL)
        OR (evening_start IS NOT NULL AND evening_end IS NOT NULL AND evening_start < evening_end)
    ),
    CONSTRAINT listing_availability_dates_full_day_order CHECK (
        (full_day_check_in IS NULL AND full_day_check_out IS NULL)
        OR (
            full_day_check_in IS NOT NULL
            AND full_day_check_out IS NOT NULL
            AND full_day_check_in < full_day_check_out
        )
    ),
    CONSTRAINT listing_availability_dates_sessions_do_not_overlap CHECK (
        morning_end IS NULL
        OR evening_start IS NULL
        OR morning_end <= evening_start
        OR evening_end <= morning_start
    ),
    CONSTRAINT listing_availability_dates_prices_nonnegative CHECK (
        (morning_price IS NULL OR morning_price >= 0)
        AND (evening_price IS NULL OR evening_price >= 0)
        AND (full_day_price IS NULL OR full_day_price >= 0)
    )
);

-- One row per listing and date. Transactions lock this row with
-- SELECT ... FOR UPDATE so two requests cannot pass the availability
-- check together. The exclusion constraint below is the database backstop.
CREATE TABLE IF NOT EXISTS listing_date_guards (
    listing_key TEXT NOT NULL,
    stay_date DATE NOT NULL,
    PRIMARY KEY (listing_key, stay_date)
);

CREATE TABLE IF NOT EXISTS booking_requests (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reference_code TEXT NOT NULL UNIQUE,
    listing_key TEXT NOT NULL REFERENCES listing_booking_profiles(listing_key) ON DELETE RESTRICT,
    chalet_id BIGINT REFERENCES chalets(id) ON DELETE SET NULL,
    customer_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    stay_date DATE NOT NULL,
    mode TEXT NOT NULL CHECK (mode IN ('full_day', 'morning', 'evening')),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    price NUMERIC(10, 2),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'confirmed', 'rejected', 'cancelled')
    ),
    block_start TIMESTAMP,
    block_end TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (start_time < end_time),
    CHECK (price IS NULL OR price >= 0),
    CHECK (
        (block_start IS NULL AND block_end IS NULL)
        OR (block_start IS NOT NULL AND block_end IS NOT NULL AND block_start < block_end)
    )
);

CREATE INDEX IF NOT EXISTS idx_booking_requests_customer
    ON booking_requests(customer_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_booking_requests_listing_date
    ON booking_requests(listing_key, stay_date, status);

CREATE OR REPLACE FUNCTION booking_requests_set_block()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IN ('pending', 'confirmed') THEN
        IF NEW.mode = 'full_day' THEN
            NEW.block_start := NEW.stay_date::timestamp;
            NEW.block_end := (NEW.stay_date + 1)::timestamp;
        ELSE
            NEW.block_start := NEW.stay_date + NEW.start_time;
            NEW.block_end := NEW.stay_date + NEW.end_time;
        END IF;
    ELSE
        NEW.block_start := NULL;
        NEW.block_end := NULL;
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS booking_requests_set_block ON booking_requests;
CREATE TRIGGER booking_requests_set_block
BEFORE INSERT OR UPDATE ON booking_requests
FOR EACH ROW
EXECUTE PROCEDURE booking_requests_set_block();

ALTER TABLE booking_requests
    DROP CONSTRAINT IF EXISTS booking_requests_no_overlap;

ALTER TABLE booking_requests
    ADD CONSTRAINT booking_requests_no_overlap
    EXCLUDE USING gist (
        listing_key WITH =,
        tsrange(block_start, block_end, '[)') WITH &&
    )
    WHERE (status IN ('pending', 'confirmed'));
