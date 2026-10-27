const { BookingError } = require("./errors");

const MODES = ["full_day", "morning", "evening"];
const BLOCKING_STATUSES = new Set(["pending", "confirmed"]);
const LISTING_KEY = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function assertListingKey(value) {
  if (typeof value !== "string" || !LISTING_KEY.test(value)) {
    throw new BookingError(
      "invalid_listing",
      "The chalet id is not valid.",
    );
  }
  return value;
}

function parseTime(value, label) {
  if (typeof value !== "string" || !/^\d{2}:\d{2}$/.test(value)) {
    throw new BookingError(
      "invalid_time_range",
      `${label} must be a 24-hour HH:MM time.`,
    );
  }
  const [hour, minute] = value.split(":").map(Number);
  if (hour > 23 || minute > 59) {
    throw new BookingError(
      "invalid_time_range",
      `${label} must be a 24-hour HH:MM time.`,
    );
  }
  return { start: value, minutes: hour * 60 + minute };
}

function requireWindow(startValue, endValue, label) {
  const start = parseTime(startValue, `${label} start`);
  const end = parseTime(endValue, `${label} end`);
  if (start.minutes === end.minutes) {
    throw new BookingError(
      "invalid_time_range",
      `${label} start time must be before its end time.`,
    );
  }
  if (start.minutes > end.minutes) {
    throw new BookingError(
      "overnight_not_supported",
      "Overnight sessions are not supported. The end time has to be later on the same day.",
    );
  }
  return { start: start.start, end: end.start };
}

function toMinutes(value) {
  const [hour, minute] = value.split(":").map(Number);
  return hour * 60 + minute;
}

function rangesOverlap(left, right) {
  return toMinutes(left.start) < toMinutes(right.end) &&
    toMinutes(right.start) < toMinutes(left.end);
}

function assertDate(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new BookingError("invalid_date", "The date must be YYYY-MM-DD.");
  }
  const [year, month, day] = value.split("-").map(Number);
  const utc = new Date(Date.UTC(year, month - 1, day));
  if (
    utc.getUTCFullYear() !== year ||
    utc.getUTCMonth() !== month - 1 ||
    utc.getUTCDate() !== day
  ) {
    throw new BookingError("invalid_date", "The date is not a real calendar day.");
  }
  return value;
}

function todayInPalestine(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Hebron",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

function assertMonthQuery(query) {
  const year = Number(query.year);
  const month = Number(query.month);
  if (!Number.isInteger(year) || year < 2000 || year > 2100) {
    throw new BookingError("invalid_date", "year must be a four-digit year.");
  }
  if (!Number.isInteger(month) || month < 1 || month > 12) {
    throw new BookingError("invalid_date", "month must be a number from 1 to 12.");
  }
  return { year, month };
}

function daysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function isoDate(year, month, day) {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function monthBounds(year, month) {
  return {
    from: isoDate(year, month, 1),
    to: isoDate(year, month, daysInMonth(year, month)),
  };
}

function assertMode(mode) {
  if (!MODES.includes(mode)) {
    throw new BookingError(
      "invalid_mode",
      "Booking mode must be full_day, morning, or evening.",
    );
  }
  return mode;
}

function optionalPrice(value, label) {
  if (value === undefined || value === null || value === "") return null;
  const price = Number(value);
  if (!Number.isFinite(price) || price < 0) {
    throw new BookingError(
      "invalid_price",
      `${label} must be a non-negative number when it is supplied.`,
    );
  }
  return Math.round(price * 100) / 100;
}

function requireBoolean(value, label) {
  if (typeof value !== "boolean") {
    throw new BookingError("invalid_config", `${label} must be true or false.`);
  }
  return value;
}

module.exports = {
  MODES,
  BLOCKING_STATUSES,
  assertListingKey,
  requireWindow,
  rangesOverlap,
  assertDate,
  todayInPalestine,
  assertMonthQuery,
  daysInMonth,
  isoDate,
  monthBounds,
  assertMode,
  optionalPrice,
  requireBoolean,
};
