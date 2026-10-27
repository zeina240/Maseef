-- MASEEF authentication session migration.
-- DO NOT RUN until this file has been reviewed and explicitly approved.
-- This file only adds auth_sessions. It does not DROP, TRUNCATE, ALTER,
-- or INSERT into users, chalets, bookings, reviews, favorites, or the
-- booking tables from 001_session_bookings.sql.
-- It does not create accounts, assign the admin role, or link a chalet
-- to an owner. Listing ownership stays a separate approved step.
--
-- Prerequisite: the existing users table from schema.sql.
-- Apply 001_session_bookings.sql separately, and only after its own approval.
-- Until both migrations are approved and an owner row is linked, do not
-- mount the protected booking routes.

CREATE TABLE IF NOT EXISTS auth_sessions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT auth_sessions_token_hash_sha256 CHECK (token_hash ~ '^[0-9a-f]{64}$')
);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_user ON auth_sessions(user_id);
