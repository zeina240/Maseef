const { BookingError } = require("./errors");
const {
  BLOCKING_STATUSES,
  daysInMonth,
  isoDate,
  optionalPrice,
  rangesOverlap,
  requireBoolean,
  requireWindow,
} = require("./time");

function requestsConflict(left, right) {
  if (left.listingKey !== right.listingKey) return false;
  if (left.stayDate !== right.stayDate) return false;
  if (left.id != null && right.id != null && left.id === right.id) return false;
  if (!BLOCKING_STATUSES.has(left.status) || !BLOCKING_STATUSES.has(right.status)) {
    return false;
  }
  if (left.mode === "full_day" || right.mode === "full_day") return true;
  return rangesOverlap(left, right);
}

function readPrices(input) {
  return {
    fullDay: optionalPrice(input.fullDayPrice, "Full-day price"),
    morning: optionalPrice(input.morningPrice, "Morning price"),
    evening: optionalPrice(input.eveningPrice, "Evening price"),
  };
}

function validateProfile(input) {
  const offersFullDay = requireBoolean(input.offersFullDay, "offersFullDay");
  const offersSessions = requireBoolean(input.offersSessions, "offersSessions");
  if (!offersFullDay && !offersSessions) {
    throw new BookingError(
      "mode_not_offered",
      "Choose full-day booking, session booking, or both.",
    );
  }

  const fullDay = offersFullDay
    ? requireWindow(input.fullDayCheckIn, input.fullDayCheckOut, "Full day")
    : null;
  if (!offersFullDay && (input.fullDayCheckIn != null || input.fullDayCheckOut != null)) {
    throw new BookingError(
      "invalid_time_range",
      "Full-day times require full-day booking to be offered.",
    );
  }

  if (
    !offersSessions &&
    (input.morningStart != null ||
      input.morningEnd != null ||
      input.eveningStart != null ||
      input.eveningEnd != null)
  ) {
    throw new BookingError(
      "invalid_time_range",
      "Session times require session booking to be offered.",
    );
  }

  let morning = null;
  let evening = null;
  if (offersSessions) {
    if (input.morningStart != null || input.morningEnd != null) {
      morning = requireWindow(input.morningStart, input.morningEnd, "Morning");
    }
    if (input.eveningStart != null || input.eveningEnd != null) {
      evening = requireWindow(input.eveningStart, input.eveningEnd, "Evening");
    }
    if (!morning && !evening) {
      throw new BookingError(
        "invalid_time_range",
        "Session booking needs a morning window, an evening window, or both.",
      );
    }
    if (morning && evening && rangesOverlap(morning, evening)) {
      throw new BookingError(
        "overlapping_windows",
        "Morning and evening times overlap.",
      );
    }
  }

  return {
    offersFullDay,
    offersSessions,
    fullDay,
    morning,
    evening,
    prices: readPrices(input),
  };
}

function optionalWindow(start, end, label) {
  if (start == null && end == null) return null;
  return requireWindow(start, end, label);
}

function validateDateRow(input) {
  const date = input.date;
  const closed = requireBoolean(input.closed, "closed");
  const offersFullDay = input.offersFullDay == null
    ? null
    : requireBoolean(input.offersFullDay, "offersFullDay");
  const offersSessions = input.offersSessions == null
    ? null
    : requireBoolean(input.offersSessions, "offersSessions");
  const fullDay = optionalWindow(input.fullDayCheckIn, input.fullDayCheckOut, "Full day");
  const morning = optionalWindow(input.morningStart, input.morningEnd, "Morning");
  const evening = optionalWindow(input.eveningStart, input.eveningEnd, "Evening");
  if (morning && evening && rangesOverlap(morning, evening)) {
    throw new BookingError(
      "overlapping_windows",
      "Morning and evening times overlap.",
    );
  }
  return {
    date,
    closed,
    offersFullDay,
    offersSessions,
    fullDay,
    morning,
    evening,
    prices: readPrices(input),
  };
}

function effectiveSchedule(profile, dateRow) {
  const offersFullDay = dateRow?.offersFullDay ?? profile.offersFullDay;
  const offersSessions = dateRow?.offersSessions ?? profile.offersSessions;
  return {
    offersFullDay,
    offersSessions,
    fullDay: dateRow?.fullDay ?? profile.fullDay,
    morning: offersSessions ? (dateRow?.morning ?? profile.morning) : null,
    evening: offersSessions ? (dateRow?.evening ?? profile.evening) : null,
    prices: {
      fullDay: dateRow?.prices?.fullDay ?? profile.prices.fullDay,
      morning: dateRow?.prices?.morning ?? profile.prices.morning,
      evening: dateRow?.prices?.evening ?? profile.prices.evening,
    },
  };
}

function windowFor(schedule, mode) {
  if (mode === "full_day") return schedule.offersFullDay ? schedule.fullDay : null;
  if (mode === "morning") return schedule.morning;
  if (mode === "evening") return schedule.evening;
  return null;
}

function priceFor(schedule, mode) {
  if (mode === "full_day") return schedule.prices.fullDay;
  if (mode === "morning") return schedule.prices.morning;
  if (mode === "evening") return schedule.prices.evening;
  return null;
}

function modeStatus(schedule, mode, requests, listingKey, stayDate) {
  const window = windowFor(schedule, mode);
  if (!window) return null;
  const candidate = {
    listingKey,
    stayDate,
    mode,
    status: "pending",
    start: window.start,
    end: window.end,
  };
  const conflicts = requests.filter((request) => requestsConflict(request, candidate));
  let status = "available";
  if (conflicts.some((request) => request.status === "confirmed")) status = "booked";
  else if (conflicts.some((request) => request.status === "pending")) status = "pending";
  return {
    status,
    start: window.start,
    end: window.end,
    price: priceFor(schedule, mode),
  };
}

function rollupState(modes) {
  const offered = Object.values(modes);
  if (offered.length === 0) return "unavailable";
  const available = offered.filter((mode) => mode.status === "available");
  const pending = offered.filter((mode) => mode.status === "pending");
  const booked = offered.filter((mode) => mode.status === "booked");
  if (available.length === offered.length) return "available";
  if (available.length > 0 && (pending.length > 0 || booked.length > 0)) return "partial";
  if (booked.length === offered.length) return "booked";
  if (pending.length > 0 && available.length === 0) return "pending";
  return "unavailable";
}

function buildMonth({ year, month, profile, dateRows, requests }) {
  const byDate = new Map(dateRows.map((row) => [row.date, row]));
  const days = [];
  for (let day = 1; day <= daysInMonth(year, month); day += 1) {
    const date = isoDate(year, month, day);
    const dateRow = byDate.get(date) ?? null;
    const dayRequests = requests.filter((request) => request.stayDate === date);
    if (!dateRow) {
      days.push({ date, state: "unavailable", modes: {} });
      continue;
    }
    if (dateRow.closed) {
      days.push({ date, state: "closed", modes: {} });
      continue;
    }
    const schedule = effectiveSchedule(profile, dateRow);
    const modes = {};
    for (const mode of ["full_day", "morning", "evening"]) {
      const described = modeStatus(schedule, mode, dayRequests, profile.listingKey, date);
      if (described) modes[mode] = described;
    }
    days.push({ date, state: rollupState(modes), modes });
  }
  return days;
}

module.exports = {
  requestsConflict,
  validateProfile,
  validateDateRow,
  effectiveSchedule,
  windowFor,
  priceFor,
  buildMonth,
};
