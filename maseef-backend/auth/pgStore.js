function createPgAuthStore(pool) {
  return {
    async insertUser(input) {
      if (input.role !== "customer" && input.role !== "owner") {
        const error = new Error("Refusing to store a non-public role.");
        error.code = "invalid_role";
        throw error;
      }

      const result = await pool.query(
        `INSERT INTO users (full_name, email, password_hash, phone, role)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, full_name, email, phone, role`,
        [input.fullName, input.email, input.passwordHash, input.phone, input.role],
      );
      return rowToUser(result.rows[0]);
    },

    async findUserByEmail(email) {
      const result = await pool.query(
        `SELECT id, full_name, email, password_hash, phone, role
         FROM users
         WHERE lower(email) = $1`,
        [email],
      );
      if (!result.rowCount) return null;
      return rowToUser(result.rows[0], { includeHash: true });
    },

    async findUserById(id) {
      const result = await pool.query(
        `SELECT id, full_name, email, phone, role
         FROM users
         WHERE id = $1`,
        [id],
      );
      if (!result.rowCount) return null;
      return rowToUser(result.rows[0]);
    },

    async findUserWithHashById(id) {
      // The id comes from a token, so refuse anything that is not an integer
      // before it reaches a BIGINT comparison.
      if (!/^\d{1,18}$/.test(String(id))) return null;
      const result = await pool.query(
        `SELECT id, full_name, email, password_hash, phone, role
         FROM users
         WHERE id = $1`,
        [id],
      );
      if (!result.rowCount) return null;
      return rowToUser(result.rows[0], { includeHash: true });
    },

    // Only changes the row if the password is still the one the reset link was
    // issued for, which makes a link single-use even under concurrent requests.
    async replacePasswordHash(userId, oldHash, newHash) {
      const result = await pool.query(
        `UPDATE users
         SET password_hash = $3
         WHERE id = $1 AND password_hash = $2`,
        [userId, oldHash, newHash],
      );
      return result.rowCount > 0;
    },

    async revokeUserSessions(userId, now) {
      await pool.query(
        `UPDATE auth_sessions
         SET revoked_at = $2
         WHERE user_id = $1 AND revoked_at IS NULL`,
        [userId, now],
      );
    },

    async insertSession({ userId, tokenHash, expiresAt }) {
      const result = await pool.query(
        `INSERT INTO auth_sessions (user_id, token_hash, expires_at)
         VALUES ($1, $2, $3)
         RETURNING id, expires_at`,
        [userId, tokenHash, expiresAt],
      );
      return {
        id: result.rows[0].id,
        expiresAt: new Date(result.rows[0].expires_at).toISOString(),
      };
    },

    async findActiveSession(tokenHash, now) {
      const result = await pool.query(
        `SELECT s.id AS session_id, s.expires_at,
                u.id, u.full_name, u.email, u.phone, u.role
         FROM auth_sessions s
         JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = $1
           AND s.revoked_at IS NULL
           AND s.expires_at > $2`,
        [tokenHash, now],
      );
      if (!result.rowCount) return null;
      const row = result.rows[0];
      return {
        sessionId: row.session_id,
        expiresAt: new Date(row.expires_at).toISOString(),
        user: rowToUser(row),
      };
    },

    async revokeSession(tokenHash, now) {
      const result = await pool.query(
        `UPDATE auth_sessions
         SET revoked_at = $2
         WHERE token_hash = $1
           AND revoked_at IS NULL
           AND expires_at > $2
         RETURNING id`,
        [tokenHash, now],
      );
      return result.rowCount > 0;
    },

    async transaction(work) {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        const result = await work(createPgAuthStore(client));
        await client.query("COMMIT");
        return result;
      } catch (error) {
        try {
          await client.query("ROLLBACK");
        } catch {
          // The original error is the one the caller needs.
        }
        throw error;
      } finally {
        client.release();
      }
    },
  };
}

function rowToUser(row, { includeHash = false } = {}) {
  const user = {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    phone: row.phone ?? null,
    role: row.role,
  };
  if (includeHash) user.passwordHash = row.password_hash;
  return user;
}

module.exports = { createPgAuthStore };
