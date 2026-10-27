const crypto = require("crypto");
const { BookingError } = require("./errors");
const {
  buildMonth,
  effectiveSchedule,
  priceFor,
  requestsConflict,
  validateDateRow,
  validateProfile,
  windowFor,
} = require("./conflicts");
const {
  assertDate,
  assertListingKey,
  assertMode,
  assertMonthQuery,
  monthBounds,
  rangesOverlap,
  todayInPalestine,
} = require("./time");

function publicConfig(profile) {
  return {
    listingKey: profile.listingKey,
    offersFullDay: profile.offersFullDay,
    offersSessions: profile.offersSessions,
    fullDay: profile.fullDay,
    morning: profile.morning,
    evening: profile.evening,
    prices: profile.prices,
    overnightSessionsSupported: false,
  };
}

function publicRequest(request) {
  return {
    id: request.id,
    reference: request.reference,
    listingKey: request.listingKey,
    stayDate: request.stayDate,
    mode: request.mode,
    start: request.start,
    end: request.end,
    price: request.price,
    status: request.status,
    createdAt: request.createdAt,
    updatedAt: request.updatedAt,
  };
}

function assertCustomer(actor) {
  if (!actor || actor.id == null) {
    throw new BookingError(
      "authentication_not_configured",
      "A signed-in customer account is required.",
      401,
    );
  }
  if (actor.role !== "customer") {
    throw new BookingError(
      "forbidden",
      "Only a customer account can do that.",
      403,
    );
  }
}

function assertOwner(actor, profile) {
  if (!actor || actor.id == null) {
    throw new BookingError(
      "authentication_not_configured",
      "A signed-in owner account is required.",
      401,
    );
  }
  if (actor.role !== "owner") {
    throw new BookingError("forbidden", "Only the chalet owner can do that.", 403);
  }
  if (!profile || profile.ownerUserId == null) {
    throw new BookingError(
      "owner_not_linked",
      "This chalet is not linked to an owner account yet.",
      403,
    );
  }
  if (String(actor.id) !== String(profile.ownerUserId)) {
    throw new BookingError(
      "forbidden",
      "This chalet belongs to a different owner.",
      403,
    );
  }
}

function stamp() {
  return new Date().toISOString();
}

function newReference() {
  return `MS-${crypto.randomBytes(4).toString("hex").toUpperCase()}`;
}

async function publicMonth(store, listingKey, query) {
  const key = assertListingKey(listingKey);
  const { year, month } = assertMonthQuery(query);
  const profile = await store.getProfile(key);
  if (!profile) {
    return {
      configured: false,
      reason: "not_configured",
      listingKey: key,
      year,
      month,
      days: [],
    };
  }
  const { from, to } = monthBounds(year, month);
  const [dateRows, requests] = await Promise.all([
    store.listDates(key, from, to),
    store.listBlockingRequests(key, from, to),
  ]);
  return {
    configured: true,
    reason: "configured",
    listingKey: key,
    year,
    month,
    overnightSessionsSupported: false,
    config: publicConfig(profile),
    days: buildMonth({
      year,
      month,
      profile,
      dateRows,
      requests,
    }),
  };
}

async function publicConfigFor(store, listingKey) {
  const key = assertListingKey(listingKey);
  const profile = await store.getProfile(key);
  if (!profile) {
    return { configured: false, reason: "not_configured", listingKey: key };
  }
  return { configured: true, reason: "configured", ...publicConfig(profile) };
}

async function saveProfile(store, actor, listingKey, input) {
  const key = assertListingKey(listingKey);
  const profile = await store.getProfile(key);
  assertOwner(actor, profile);
  const validated = validateProfile(input);
  return store.putProfile({
    ...profile,
    ...validated,
    listingKey: key,
    updatedAt: stamp(),
  });
}

async function saveDates(store, actor, listingKey, input) {
  const key = assertListingKey(listingKey);
  const profile = await store.getProfile(key);
  assertOwner(actor, profile);
  if (!Array.isArray(input.dates) || input.dates.length === 0) {
    throw new BookingError("invalid_date", "Provide at least one date.");
  }
  const saved = [];
  for (const entry of input.dates) {
    const date = assertDate(entry.date);
    const validated = validateDateRow({ ...entry, date });
    const schedule = effectiveSchedule(profile, validated);
    if (schedule.morning && schedule.evening && rangesOverlap(schedule.morning, schedule.evening)) {
      throw new BookingError(
        "overlapping_windows",
        "The date's morning and evening times overlap.",
      );
    }
    saved.push(await store.putDate({ ...validated, listingKey: key }));
  }
  return saved;
}

async function submitRequest(store, actor, listingKey, input, now = new Date()) {
  assertCustomer(actor);
  const key = assertListingKey(listingKey);
  const stayDate = assertDate(input.stayDate);
  const mode = assertMode(input.mode);
  if (stayDate < todayInPalestine(now)) {
    throw new BookingError("invalid_date", "The selected date is in the past.");
  }
  const profile = await store.getProfile(key);
  if (!profile) {
    throw new BookingError(
      "availability_not_configured",
      "Availability has not been provided for this chalet.",
      409,
    );
  }

  return store.withLock(`${key}|${stayDate}`, async () => {
    const dateRow = await store.getDate(key, stayDate);
    if (!dateRow || dateRow.closed) {
      throw new BookingError(
        dateRow?.closed ? "date_closed" : "date_unavailable",
        dateRow?.closed
          ? "This date is closed."
          : "This date is not available.",
        409,
      );
    }
    const schedule = effectiveSchedule(profile, dateRow);
    const window = windowFor(schedule, mode);
    if (!window) {
      throw new BookingError(
        "mode_not_offered",
        "That booking mode is not offered on this date.",
        409,
      );
    }
    const blocking = await store.listBlockingRequests(key, stayDate, stayDate);
    const candidate = {
      listingKey: key,
      stayDate,
      mode,
      status: "pending",
      start: window.start,
      end: window.end,
    };
    if (blocking.some((request) => requestsConflict(request, candidate))) {
      throw new BookingError(
        "slot_conflict",
        "That date and booking mode is no longer available.",
        409,
      );
    }
    const createdAt = stamp();
    return store.insertRequest({
      reference: newReference(),
      listingKey: key,
      customerUserId: actor.id,
      stayDate,
      mode,
      start: window.start,
      end: window.end,
      price: priceFor(schedule, mode),
      status: "pending",
      createdAt,
      updatedAt: createdAt,
    });
  });
}

async function changeStatus(store, actor, requestId, nextStatus) {
  const existing = await store.getRequest(requestId);
  if (!existing) {
    throw new BookingError("not_found", "Booking request not found.", 404);
  }
  const profile = await store.getProfile(existing.listingKey);
  if (nextStatus === "cancelled" && actor?.role === "customer") {
    assertCustomer(actor);
    if (String(actor.id) !== String(existing.customerUserId)) {
      throw new BookingError("forbidden", "You can only cancel your own request.", 403);
    }
  } else {
    assertOwner(actor, profile);
  }
  if (!["confirmed", "rejected", "cancelled"].includes(nextStatus)) {
    throw new BookingError("invalid_status", "That status change is not allowed.");
  }

  return store.withLock(`${existing.listingKey}|${existing.stayDate}`, async () => {
    const current = await store.getRequest(requestId);
    if (!current) {
      throw new BookingError("not_found", "Booking request not found.", 404);
    }
    if (actor.role === "customer" && current.status !== "pending") {
      throw new BookingError(
        "request_not_pending",
        "A customer can cancel only a pending request.",
        409,
      );
    }
    const canChange = current.status === "pending" ||
      (current.status === "confirmed" && nextStatus === "cancelled");
    if (!canChange) {
      throw new BookingError(
        "request_not_pending",
        "This request can no longer be changed.",
        409,
      );
    }
    let start = current.start;
    let end = current.end;
    if (nextStatus === "confirmed") {
      const checked = await recheckForConfirmation(store, profile, current);
      start = checked.start;
      end = checked.end;
      await rejectConflictingPendings(store, current, checked);
    }
    return store.updateRequest({
      ...current,
      start,
      end,
      status: nextStatus,
      updatedAt: stamp(),
    });
  });
}

async function recheckForConfirmation(store, profile, current) {
  const dateRow = await store.getDate(current.listingKey, current.stayDate);
  if (!dateRow || dateRow.closed) {
    throw new BookingError(
      dateRow?.closed ? "date_closed" : "date_unavailable",
      "This date is no longer open.",
      409,
    );
  }
  const schedule = effectiveSchedule(profile, dateRow);
  const window = windowFor(schedule, current.mode);
  if (!window) {
    throw new BookingError(
      "mode_not_offered",
      "That booking mode is no longer offered.",
      409,
    );
  }
  const blocking = await store.listBlockingRequests(
    current.listingKey,
    current.stayDate,
    current.stayDate,
  );
  const candidate = {
    ...current,
    start: window.start,
    end: window.end,
    status: "confirmed",
  };
  const confirmedConflict = blocking.some((request) => (
    request.status === "confirmed" && requestsConflict(request, candidate)
  ));
  if (confirmedConflict) {
    throw new BookingError(
      "slot_conflict",
      "Another confirmed reservation already has this date.",
      409,
    );
  }
  return { start: window.start, end: window.end };
}

async function rejectConflictingPendings(store, current, checked) {
  const blocking = await store.listBlockingRequests(
    current.listingKey,
    current.stayDate,
    current.stayDate,
  );
  const candidate = {
    ...current,
    ...checked,
    status: "confirmed",
  };
  for (const request of blocking) {
    if (request.id === current.id || request.status !== "pending") continue;
    if (!requestsConflict(request, candidate)) continue;
    await store.updateRequest({
      ...request,
      status: "rejected",
      updatedAt: stamp(),
    });
  }
}

async function listCustomerRequests(store, actor) {
  assertCustomer(actor);
  const rows = await store.listRequestsForCustomer(actor.id);
  return rows.map(publicRequest);
}

async function listOwnerRequests(store, actor, listingKey) {
  const key = assertListingKey(listingKey);
  const profile = await store.getProfile(key);
  assertOwner(actor, profile);
  const rows = await store.listRequestsForOwner(actor.id);
  return rows
    .filter((request) => request.listingKey === key)
    .map(publicRequest);
}

module.exports = {
  publicMonth,
  publicConfigFor,
  publicRequest,
  saveProfile,
  saveDates,
  submitRequest,
  changeStatus,
  listCustomerRequests,
  listOwnerRequests,
};
