const { BookingError } = require("./errors");

function createPgStore(pool) {
  return {
    async getProfile(listingKey) {
      const result = await pool.query(
        `SELECT listing_key, chalet_id, owner_user_id, offers_full_day, offers_sessions,
                morning_start, morning_end, evening_start, evening_end,
                full_day_check_in, full_day_check_out,
                morning_price, evening_price, full_day_price
         FROM listing_booking_profiles
         WHERE listing_key = $1`,
        [listingKey],
      );
      return result.rowCount ? rowToProfile(result.rows[0]) : null;
    },

    async listDates(listingKey, from, to) {
      const result = await pool.query(
        `SELECT listing_key, to_char(stay_date, 'YYYY-MM-DD') AS stay_date,
                is_closed, offers_full_day, offers_sessions,
                morning_start, morning_end, evening_start, evening_end,
                full_day_check_in, full_day_check_out,
                morning_price, evening_price, full_day_price
         FROM listing_availability_dates
         WHERE listing_key = $1 AND stay_date BETWEEN $2 AND $3
         ORDER BY stay_date`,
        [listingKey, from, to],
      );
      return result.rows.map(rowToDate);
    },

    async listBlockingRequests(listingKey, from, to) {
      const result = await pool.query(
        `SELECT id, reference_code, listing_key, customer_user_id,
                to_char(stay_date, 'YYYY-MM-DD') AS stay_date, mode,
                start_time, end_time, price, status, created_at, updated_at
         FROM booking_requests
         WHERE listing_key = $1
           AND stay_date BETWEEN $2 AND $3
           AND status IN ('pending', 'confirmed')`,
        [listingKey, from, to],
      );
      return result.rows.map(rowToRequest);
    },

    async withLock() {
      throw new BookingError(
        "authentication_not_configured",
        "Booking changes stay disabled until the booking migration and owner link are approved.",
        401,
      );
    },
  };
}

function hhmm(value) {
  if (value == null) return null;
  return String(value).slice(0, 5);
}

function windowFrom(start, end) {
  if (start == null || end == null) return null;
  return { start: hhmm(start), end: hhmm(end) };
}

function price(value) {
  if (value == null) return null;
  return Number(value);
}

function rowToProfile(row) {
  return {
    listingKey: row.listing_key,
    chaletId: row.chalet_id,
    ownerUserId: row.owner_user_id,
    offersFullDay: row.offers_full_day,
    offersSessions: row.offers_sessions,
    fullDay: windowFrom(row.full_day_check_in, row.full_day_check_out),
    morning: windowFrom(row.morning_start, row.morning_end),
    evening: windowFrom(row.evening_start, row.evening_end),
    prices: {
      fullDay: price(row.full_day_price),
      morning: price(row.morning_price),
      evening: price(row.evening_price),
    },
  };
}

function rowToDate(row) {
  return {
    listingKey: row.listing_key,
    date: typeof row.stay_date === "string"
      ? row.stay_date.slice(0, 10)
      : row.stay_date.toISOString().slice(0, 10),
    closed: row.is_closed,
    offersFullDay: row.offers_full_day,
    offersSessions: row.offers_sessions,
    fullDay: windowFrom(row.full_day_check_in, row.full_day_check_out),
    morning: windowFrom(row.morning_start, row.morning_end),
    evening: windowFrom(row.evening_start, row.evening_end),
    prices: {
      fullDay: price(row.full_day_price),
      morning: price(row.morning_price),
      evening: price(row.evening_price),
    },
  };
}

function rowToRequest(row) {
  return {
    id: Number(row.id),
    reference: row.reference_code,
    listingKey: row.listing_key,
    customerUserId: Number(row.customer_user_id),
    stayDate: typeof row.stay_date === "string"
      ? row.stay_date.slice(0, 10)
      : row.stay_date.toISOString().slice(0, 10),
    mode: row.mode,
    start: hhmm(row.start_time),
    end: hhmm(row.end_time),
    price: price(row.price),
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

module.exports = { createPgStore };
