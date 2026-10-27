const assert = require("node:assert/strict");
const http = require("node:http");
const test = require("node:test");
const express = require("express");
const { BookingError, toPublicAvailabilityError } = require("../booking/errors");
const { requestsConflict, validateProfile } = require("../booking/conflicts");
const { MemoryBookingStore } = require("../booking/memoryStore");
const { createProtectedBookingRouter } = require("../booking/routes");
const service = require("../booking/service");
const { todayInPalestine } = require("../booking/time");
const { createApp } = require("../server");

const customer = { id: 9, role: "customer" };
const otherCustomer = { id: 10, role: "customer" };
const owner = { id: 5, role: "owner" };
const otherOwner = { id: 6, role: "owner" };

function plusDays(days) {
  const [year, month, day] = todayInPalestine().split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day + days));
  return date.toISOString().slice(0, 10);
}

function profile(overrides = {}) {
  return {
    listingKey: "hareem-sultan",
    ownerUserId: owner.id,
    chaletId: null,
    offersFullDay: true,
    offersSessions: true,
    fullDay: { start: "08:00", end: "22:00" },
    morning: { start: "08:00", end: "13:00" },
    evening: { start: "14:00", end: "22:00" },
    prices: { fullDay: null, morning: null, evening: null },
    ...overrides,
  };
}

function openDate(date, overrides = {}) {
  return {
    listingKey: "hareem-sultan",
    date,
    closed: false,
    offersFullDay: null,
    offersSessions: null,
    fullDay: null,
    morning: null,
    evening: null,
    prices: { fullDay: null, morning: null, evening: null },
    ...overrides,
  };
}

async function readyStore(date = plusDays(10)) {
  const store = new MemoryBookingStore();
  await store.putProfile(profile());
  await store.putDate(openDate(date));
  return { store, date };
}

function routesOf(app) {
  return app.router.stack
    .filter((layer) => layer.route)
    .flatMap((layer) => (
      Object.entries(layer.route.methods)
        .filter(([, enabled]) => enabled)
        .map(([method]) => `${method.toUpperCase()} ${layer.route.path}`)
    ));
}

function listen(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function request(server, method, path, { user, body } = {}) {
  const payload = body == null ? null : JSON.stringify(body);
  const { port } = server.address();
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port,
        path,
        method,
        headers: {
          "content-type": "application/json",
          ...(user ? { "x-test-user": JSON.stringify(user) } : {}),
          ...(payload ? { "content-length": Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const raw = Buffer.concat(chunks).toString("utf8");
          resolve({
            status: res.statusCode,
            body: raw ? JSON.parse(raw) : null,
          });
        });
      },
    );
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

test("full-day reservation conflicts with morning and evening on that date", () => {
  const fullDay = {
    id: 1,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "full_day",
    status: "confirmed",
    start: "16:00",
    end: "22:00",
  };
  assert.equal(requestsConflict(fullDay, {
    id: 2,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "morning",
    status: "pending",
    start: "08:00",
    end: "12:00",
  }), true);
  assert.equal(requestsConflict(fullDay, {
    id: 3,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "evening",
    status: "confirmed",
    start: "18:00",
    end: "21:00",
  }), true);
});

test("morning and evening can share a date when their windows do not overlap", () => {
  const morning = {
    id: 1,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "morning",
    status: "confirmed",
    start: "08:00",
    end: "13:00",
  };
  assert.equal(requestsConflict(morning, {
    id: 2,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "evening",
    status: "pending",
    start: "13:00",
    end: "22:00",
  }), false);
  assert.equal(requestsConflict(morning, {
    id: 3,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "evening",
    status: "pending",
    start: "12:00",
    end: "18:00",
  }), true);
});

test("rejected and cancelled requests do not keep the date blocked", () => {
  const morning = {
    id: 1,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "morning",
    status: "rejected",
    start: "08:00",
    end: "13:00",
  };
  assert.equal(requestsConflict(morning, {
    id: 2,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "morning",
    status: "pending",
    start: "08:00",
    end: "13:00",
  }), false);
  assert.equal(requestsConflict({ ...morning, status: "cancelled" }, {
    id: 2,
    listingKey: "hareem-sultan",
    stayDate: "2026-11-01",
    mode: "full_day",
    status: "confirmed",
    start: "08:00",
    end: "22:00",
  }), false);
});

test("overlapping or overnight owner windows are rejected", () => {
  assert.throws(
    () => validateProfile({
      offersFullDay: false,
      offersSessions: true,
      morningStart: "08:00",
      morningEnd: "16:00",
      eveningStart: "15:00",
      eveningEnd: "22:00",
    }),
    (error) => error.code === "overlapping_windows",
  );
  assert.throws(
    () => validateProfile({
      offersFullDay: true,
      offersSessions: false,
      fullDayCheckIn: "18:00",
      fullDayCheckOut: "02:00",
    }),
    (error) => error.code === "overnight_not_supported",
  );
  const saved = validateProfile({
    offersFullDay: true,
    offersSessions: true,
    fullDayCheckIn: "08:00",
    fullDayCheckOut: "22:00",
    morningStart: "08:00",
    morningEnd: "13:00",
    eveningStart: "14:00",
    eveningEnd: "22:00",
    morningPrice: 150,
  });
  assert.equal(saved.prices.morning, 150);
  assert.equal(saved.prices.evening, null);
});

test("a missing schedule reports that availability is not configured", async () => {
  const store = new MemoryBookingStore();
  const month = await service.publicMonth(store, "hareem-sultan", {
    year: 2026,
    month: 10,
  });
  assert.equal(month.configured, false);
  assert.deepEqual(month.days, []);
});

test("closed dates and unopened dates cannot be requested", async () => {
  const date = plusDays(10);
  const closed = plusDays(11);
  const { store } = await readyStore(date);
  await store.putDate(openDate(closed, { closed: true }));

  await assert.rejects(
    service.submitRequest(store, customer, "hareem-sultan", {
      stayDate: closed,
      mode: "morning",
    }),
    (error) => error.code === "date_closed",
  );
  await assert.rejects(
    service.submitRequest(store, customer, "hareem-sultan", {
      stayDate: plusDays(20),
      mode: "evening",
    }),
    (error) => error.code === "date_unavailable",
  );
});

test("morning and evening requests coexist, and a full day blocks both", async () => {
  const date = plusDays(10);
  const { store } = await readyStore(date);
  const morning = await service.submitRequest(store, customer, "hareem-sultan", {
    stayDate: date,
    mode: "morning",
  });
  const evening = await service.submitRequest(store, otherCustomer, "hareem-sultan", {
    stayDate: date,
    mode: "evening",
  });
  assert.equal(morning.status, "pending");
  assert.equal(evening.status, "pending");
  assert.equal(morning.price, null);
  assert.match(morning.reference, /^MS-[0-9A-F]{8}$/);

  const blocked = plusDays(12);
  await store.putDate(openDate(blocked));
  await service.submitRequest(store, customer, "hareem-sultan", {
    stayDate: blocked,
    mode: "full_day",
  });
  await assert.rejects(
    service.submitRequest(store, otherCustomer, "hareem-sultan", {
      stayDate: blocked,
      mode: "morning",
    }),
    (error) => error.code === "slot_conflict",
  );
  await assert.rejects(
    service.submitRequest(store, otherCustomer, "hareem-sultan", {
      stayDate: blocked,
      mode: "evening",
    }),
    (error) => error.code === "slot_conflict",
  );
});

test("two customers cannot take the same booking at the same time", async () => {
  const date = plusDays(10);
  const { store } = await readyStore(date);
  const results = await Promise.allSettled([
    service.submitRequest(store, customer, "hareem-sultan", {
      stayDate: date,
      mode: "full_day",
    }),
    service.submitRequest(store, otherCustomer, "hareem-sultan", {
      stayDate: date,
      mode: "full_day",
    }),
  ]);
  const fulfilled = results.filter((result) => result.status === "fulfilled");
  const rejected = results.filter((result) => result.status === "rejected");
  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.equal(rejected[0].reason.code, "slot_conflict");
  assert.equal(fulfilled[0].value.status, "pending");
});

test("confirming a request fails when another confirmed reservation has the slot", async () => {
  const date = plusDays(10);
  const { store } = await readyStore(date);
  const pending = await service.submitRequest(store, customer, "hareem-sultan", {
    stayDate: date,
    mode: "morning",
  });
  await store.insertRequest({
    reference: "MS-TAKEN01",
    listingKey: "hareem-sultan",
    customerUserId: otherCustomer.id,
    stayDate: date,
    mode: "full_day",
    start: "08:00",
    end: "22:00",
    price: null,
    status: "confirmed",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });

  await assert.rejects(
    service.changeStatus(store, owner, pending.id, "confirmed"),
    (error) => error.code === "slot_conflict",
  );
  assert.equal((await store.getRequest(pending.id)).status, "pending");
});

test("the first of two conflicting confirmations keeps the slot", async () => {
  const date = plusDays(10);
  const { store } = await readyStore(date);
  const first = await store.insertRequest({
    reference: "MS-RACE0001",
    listingKey: "hareem-sultan",
    customerUserId: customer.id,
    stayDate: date,
    mode: "full_day",
    start: "08:00",
    end: "22:00",
    price: null,
    status: "pending",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
  const second = await store.insertRequest({
    reference: "MS-RACE0002",
    listingKey: "hareem-sultan",
    customerUserId: otherCustomer.id,
    stayDate: date,
    mode: "morning",
    start: "08:00",
    end: "13:00",
    price: null,
    status: "pending",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });

  const results = await Promise.allSettled([
    service.changeStatus(store, owner, first.id, "confirmed"),
    service.changeStatus(store, owner, second.id, "confirmed"),
  ]);
  const confirmed = results
    .filter((result) => result.status === "fulfilled")
    .map((result) => result.value);
  assert.equal(confirmed.length, 1);
  assert.equal(confirmed[0].status, "confirmed");
  const loserId = confirmed[0].id === first.id ? second.id : first.id;
  assert.equal((await store.getRequest(loserId)).status, "rejected");
  assert.equal(
    results.find((result) => result.status === "rejected").reason.code,
    "request_not_pending",
  );
});

test("rejecting or cancelling a request releases the date", async () => {
  const date = plusDays(10);
  const { store } = await readyStore(date);
  const pending = await service.submitRequest(store, customer, "hareem-sultan", {
    stayDate: date,
    mode: "evening",
  });
  const rejected = await service.changeStatus(store, owner, pending.id, "rejected");
  assert.equal(rejected.status, "rejected");
  const replacement = await service.submitRequest(store, otherCustomer, "hareem-sultan", {
    stayDate: date,
    mode: "evening",
  });
  assert.equal(replacement.status, "pending");

  const cancelled = await service.changeStatus(
    store,
    otherCustomer,
    replacement.id,
    "cancelled",
  );
  assert.equal(cancelled.status, "cancelled");
  const afterCancel = await service.submitRequest(store, customer, "hareem-sultan", {
    stayDate: date,
    mode: "full_day",
  });
  assert.equal(afterCancel.status, "pending");
});

test("owner schedule changes are refused for anyone except the linked owner", async () => {
  const { store, date } = await readyStore();
  await assert.rejects(
    service.saveProfile(store, null, "hareem-sultan", {
      offersFullDay: true,
      offersSessions: false,
      fullDayCheckIn: "09:00",
      fullDayCheckOut: "18:00",
    }),
    (error) => error instanceof BookingError && error.status === 401,
  );
  await assert.rejects(
    service.saveDates(store, customer, "hareem-sultan", {
      dates: [{ date, closed: true }],
    }),
    (error) => error.code === "forbidden",
  );
  await assert.rejects(
    service.saveProfile(store, otherOwner, "hareem-sultan", {
      offersFullDay: false,
      offersSessions: true,
      morningStart: "08:00",
      morningEnd: "12:00",
    }),
    (error) => error.code === "forbidden",
  );

  const unlinked = new MemoryBookingStore();
  await unlinked.putProfile(profile({ ownerUserId: null }));
  await assert.rejects(
    service.saveProfile(unlinked, owner, "hareem-sultan", {
      offersFullDay: true,
      offersSessions: false,
      fullDayCheckIn: "09:00",
      fullDayCheckOut: "18:00",
    }),
    (error) => error.code === "owner_not_linked",
  );
});

test("public routes stay readable and management routes are not mounted", async () => {
  const store = new MemoryBookingStore();
  const app = createApp({ bookingStore: store });
  const paths = routesOf(app);
  assert.equal(paths.includes("GET /api/listings/:listingKey/availability"), true);
  assert.equal(paths.includes("GET /api/listings/:listingKey/booking"), true);
  assert.equal(paths.some((path) => path.includes("/api/owner")), false);
  assert.equal(paths.some((path) => path.includes("booking-requests")), false);

  const server = await listen(app);
  try {
    const response = await request(
      server,
      "GET",
      "/api/listings/hareem-sultan/availability?year=2026&month=10",
    );
    assert.equal(response.status, 200);
    assert.equal(response.body.data.configured, false);
    assert.equal(response.body.data.reason, "not_configured");
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test("protected routes reject signed-out users and the wrong owner", async () => {
  assert.throws(
    () => createProtectedBookingRouter({ store: new MemoryBookingStore() }),
    /without authentication/,
  );

  const { store, date } = await readyStore();
  const app = express();
  app.use(express.json());
  app.use(createProtectedBookingRouter({
    store,
    authenticate(req, _res, next) {
      const header = req.header("x-test-user");
      req.user = header ? JSON.parse(header) : null;
      next();
    },
  }));
  const server = await listen(app);
  try {
    const signedOut = await request(
      server,
      "PUT",
      "/api/owner/listings/hareem-sultan/availability",
      { body: { dates: [{ date, closed: true }] } },
    );
    assert.equal(signedOut.status, 401);
    assert.equal(signedOut.body.code, "authentication_not_configured");

    const created = await request(
      server,
      "POST",
      "/api/listings/hareem-sultan/booking-requests",
      { user: customer, body: { stayDate: date, mode: "morning" } },
    );
    assert.equal(created.status, 201);
    assert.equal(created.body.data.status, "pending");
    assert.notEqual(created.body.data.status, "confirmed");

    const customerAttempt = await request(
      server,
      "POST",
      `/api/owner/booking-requests/${created.body.data.id}/accept`,
      { user: customer },
    );
    assert.equal(customerAttempt.status, 403);

    const stranger = await request(
      server,
      "POST",
      `/api/owner/booking-requests/${created.body.data.id}/accept`,
      { user: otherOwner },
    );
    assert.equal(stranger.status, 403);
    assert.equal(stranger.body.code, "forbidden");
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test("a missing booking table is reported without querying further", () => {
  const mapped = toPublicAvailabilityError({ code: "42P01" });
  assert.equal(mapped.httpStatus, 200);
  assert.equal(mapped.body.data.configured, false);
  assert.equal(mapped.body.data.reason, "storage_not_ready");
  assert.deepEqual(mapped.body.data.days, []);
});
