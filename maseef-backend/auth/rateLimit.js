// A small fixed-window limiter kept in this process's memory. It slows down
// email flooding and guessing; it resets when the server restarts and is not
// shared between several server instances (use a shared store if you scale out).

function createRateLimiter({ windowMs, max, now = () => new Date() }) {
  const hits = new Map();

  return {
    /** Returns { allowed, retryAfterSeconds } and counts this attempt. */
    take(key) {
      const current = now().getTime();
      if (hits.size > 5000) {
        for (const [k, entry] of hits) {
          if (entry.resetAt <= current) hits.delete(k);
        }
      }
      let entry = hits.get(key);
      if (!entry || entry.resetAt <= current) {
        entry = { count: 0, resetAt: current + windowMs };
        hits.set(key, entry);
      }
      entry.count += 1;
      return {
        allowed: entry.count <= max,
        retryAfterSeconds: Math.max(1, Math.ceil((entry.resetAt - current) / 1000)),
      };
    },
  };
}

module.exports = { createRateLimiter };
