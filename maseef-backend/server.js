
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const pool = require("./db");
const { mountAuthRoutes } = require("./auth/routes");
const { createPgAuthStore } = require("./auth/pgStore");
const { passwordResetFromEnv } = require("./auth/resetConfig");
const { mountPublicBookingRoutes } = require("./booking/routes");
const { createPgStore } = require("./booking/pgStore");

function createApp({ bookingStore, authStore, passwords, now, passwordReset } = {}) {
const app = express();
const store = bookingStore ?? createPgStore(pool);
const users = authStore ?? createPgAuthStore(pool);

app.use(cors());
app.use(express.json());

// الصفحة الرئيسية
app.get("/", (req, res) => {
  res.json({ message: "Welcome to MASEEF API!" });
});

// فحص اتصال قاعدة البيانات
app.get("/api/health", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW() AS time");

    res.json({
      status: "success",
      message: "Backend and database are connected!",
      databaseTime: result.rows[0].time,
    });
  } catch (error) {
    console.error("Database connection failed:", error.message);

    res.status(500).json({
      status: "error",
      message: "Database connection failed",
    });
  }
});

// عرض الشاليهات مع البحث والفلاتر
app.get("/api/chalets", async (req, res) => {
  try {
    const { city, minPrice, maxPrice, guests } = req.query;

    const conditions = ["c.is_active = TRUE"];
    const values = [];

    if (city && city.trim()) {
      values.push(`%${city.trim()}%`);
      conditions.push(`c.city ILIKE $${values.length}`);
    }

    if (minPrice !== undefined) {
      const price = Number(minPrice);

      if (!Number.isFinite(price) || price < 0) {
        return res.status(400).json({
          status: "error",
          message: "minPrice must be a valid non-negative number.",
        });
      }

      values.push(price);
      conditions.push(`c.price_per_night >= $${values.length}`);
    }

    if (maxPrice !== undefined) {
      const price = Number(maxPrice);

      if (!Number.isFinite(price) || price < 0) {
        return res.status(400).json({
          status: "error",
          message: "maxPrice must be a valid non-negative number.",
        });
      }

      values.push(price);
      conditions.push(`c.price_per_night <= $${values.length}`);
    }

    if (
      minPrice !== undefined &&
      maxPrice !== undefined &&
      Number(minPrice) > Number(maxPrice)
    ) {
      return res.status(400).json({
        status: "error",
        message: "minPrice cannot be greater than maxPrice.",
      });
    }

    if (guests !== undefined) {
      const count = Number(guests);

      if (!Number.isInteger(count) || count < 1) {
        return res.status(400).json({
          status: "error",
          message: "guests must be a positive integer.",
        });
      }

      values.push(count);
      conditions.push(`c.max_guests >= $${values.length}`);
    }

    const query = `
      SELECT
        c.id,
        c.name,
        c.description,
        c.city,
        c.address,
        c.latitude,
        c.longitude,
        c.price_per_night,
        c.max_guests,
        c.bedrooms,
        c.bathrooms,

        COALESCE(
          (
            SELECT json_agg(
              json_build_object(
                'id', ci.id,
                'image_url', ci.image_url,
                'is_primary', ci.is_primary
              )
              ORDER BY ci.is_primary DESC, ci.id
            )
            FROM chalet_images ci
            WHERE ci.chalet_id = c.id
          ),
          '[]'::json
        ) AS images,

        COALESCE(
          (
            SELECT json_agg(a.name ORDER BY a.name)
            FROM chalet_amenities ca
            JOIN amenities a ON a.id = ca.amenity_id
            WHERE ca.chalet_id = c.id
          ),
          '[]'::json
        ) AS amenities,

        COALESCE(
          (
            SELECT ROUND(AVG(r.rating)::numeric, 1)
            FROM reviews r
            WHERE r.chalet_id = c.id
          ),
          0
        ) AS average_rating,

        (
          SELECT COUNT(*)
          FROM reviews r
          WHERE r.chalet_id = c.id
        ) AS review_count

      FROM chalets c
      WHERE ${conditions.join(" AND ")}
      ORDER BY c.created_at DESC, c.id DESC;
    `;

    const result = await pool.query(query, values);

    res.json({
      status: "success",
      count: result.rows.length,
      data: result.rows,
    });
  } catch (error) {
    console.error("Failed to fetch chalets:", error.message);

    res.status(500).json({
      status: "error",
      message: "Failed to fetch chalets.",
    });
  }
});

mountAuthRoutes(app, {
  store: users,
  passwords,
  now,
  passwordReset: passwordReset ?? passwordResetFromEnv(),
});

// Protected booking routes stay unmounted. Sign-in can identify a user,
// but booking writes still need 001_session_bookings.sql and an approved
// owner link before createProtectedBookingRouter is exposed.
mountPublicBookingRoutes(app, store);
return app;
}

if (require.main === module) {
  const PORT = process.env.PORT || 5000;
  const reset = passwordResetFromEnv();
  createApp({ passwordReset: reset }).listen(PORT, () => {
    console.log(`MASEEF API is running on port ${PORT}`);
    if (reset.missing.length) {
      console.warn(
        `Password reset is OFF. Missing settings: ${reset.missing.join(", ")}`,
      );
    } else {
      console.log("Password reset email is configured.");
    }
  });
}

module.exports = { createApp };
