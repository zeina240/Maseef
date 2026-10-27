const express = require("express");
const { toPublicAvailabilityError } = require("./errors");
const service = require("./service");

function createProtectedBookingRouter({ store, authenticate }) {
  if (typeof authenticate !== "function") {
    throw new Error(
      "Refusing to expose booking management routes without authentication.",
    );
  }

  const router = express.Router();
  router.use(authenticate);

  router.get("/api/me/booking-requests", async (req, res) => {
    try {
      const data = await service.listCustomerRequests(store, req.user);
      res.json({ status: "success", data });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/api/listings/:listingKey/booking-requests", async (req, res) => {
    try {
      const created = await service.submitRequest(
        store,
        req.user,
        req.params.listingKey,
        req.body ?? {},
      );
      res.status(201).json({
        status: "success",
        data: service.publicRequest(created),
      });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/api/me/booking-requests/:id/cancel", async (req, res) => {
    try {
      const updated = await service.changeStatus(
        store,
        req.user,
        numberId(req.params.id),
        "cancelled",
      );
      res.json({ status: "success", data: service.publicRequest(updated) });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.get("/api/owner/listings/:listingKey/booking-requests", async (req, res) => {
    try {
      const data = await service.listOwnerRequests(
        store,
        req.user,
        req.params.listingKey,
      );
      res.json({ status: "success", data });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/api/owner/booking-requests/:id/accept", async (req, res) => {
    try {
      const updated = await service.changeStatus(
        store,
        req.user,
        numberId(req.params.id),
        "confirmed",
      );
      res.json({ status: "success", data: service.publicRequest(updated) });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.post("/api/owner/booking-requests/:id/reject", async (req, res) => {
    try {
      const updated = await service.changeStatus(
        store,
        req.user,
        numberId(req.params.id),
        "rejected",
      );
      res.json({ status: "success", data: service.publicRequest(updated) });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.put("/api/owner/listings/:listingKey/booking", async (req, res) => {
    try {
      const data = await service.saveProfile(
        store,
        req.user,
        req.params.listingKey,
        req.body ?? {},
      );
      res.json({ status: "success", data: servicePublicProfile(data) });
    } catch (error) {
      sendError(res, error);
    }
  });

  router.put("/api/owner/listings/:listingKey/availability", async (req, res) => {
    try {
      const data = await service.saveDates(
        store,
        req.user,
        req.params.listingKey,
        req.body ?? {},
      );
      res.json({ status: "success", data });
    } catch (error) {
      sendError(res, error);
    }
  });

  return router;
}

function servicePublicProfile(profile) {
  return {
    listingKey: profile.listingKey,
    offersFullDay: profile.offersFullDay,
    offersSessions: profile.offersSessions,
    fullDay: profile.fullDay,
    morning: profile.morning,
    evening: profile.evening,
    prices: profile.prices,
    ownerLinked: profile.ownerUserId != null,
  };
}

function numberId(value) {
  const id = Number(value);
  if (!Number.isInteger(id) || id < 1) {
    const { BookingError } = require("./errors");
    throw new BookingError("not_found", "Booking request not found.", 404);
  }
  return id;
}

function sendError(res, error) {
  const mapped = toPublicAvailabilityError(error);
  res.status(mapped.httpStatus).json(mapped.body);
}

function mountPublicBookingRoutes(app, store) {
  app.get("/api/listings/:listingKey/booking", async (req, res) => {
    try {
      const data = await service.publicConfigFor(store, req.params.listingKey);
      res.json({ status: "success", data });
    } catch (error) {
      const mapped = toPublicAvailabilityError(error);
      res.status(mapped.httpStatus).json(mapped.body);
    }
  });

  app.get("/api/listings/:listingKey/availability", async (req, res) => {
    try {
      const data = await service.publicMonth(
        store,
        req.params.listingKey,
        req.query,
      );
      res.json({ status: "success", data });
    } catch (error) {
      const mapped = toPublicAvailabilityError(error);
      res.status(mapped.httpStatus).json(mapped.body);
    }
  });
}

module.exports = {
  createProtectedBookingRouter,
  mountPublicBookingRoutes,
};
