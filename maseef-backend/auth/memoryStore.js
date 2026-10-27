class MemoryAuthStore {
  constructor() {
    this.users = [];
    this.sessions = new Map();
    this.nextUserId = 1;
    this.nextSessionId = 1;
  }

  async insertUser(input) {
    assertPublicRole(input.role);
    if (this.users.some((user) => user.email === input.email)) {
      const error = new Error("duplicate email");
      error.code = "23505";
      throw error;
    }

    const user = {
      id: this.nextUserId,
      fullName: input.fullName,
      email: input.email,
      passwordHash: input.passwordHash,
      phone: input.phone ?? null,
      role: input.role,
    };
    this.nextUserId += 1;
    this.users.push(user);
    return { ...user };
  }

  async findUserByEmail(email) {
    const user = this.users.find((row) => row.email === email);
    return user ? { ...user } : null;
  }

  async findUserById(id) {
    const user = this.users.find((row) => String(row.id) === String(id));
    return user ? { ...user } : null;
  }

  async findUserWithHashById(id) {
    return this.findUserById(id);
  }

  async replacePasswordHash(userId, oldHash, newHash) {
    const user = this.users.find((row) => String(row.id) === String(userId));
    if (!user || user.passwordHash !== oldHash) return false;
    user.passwordHash = newHash;
    return true;
  }

  async revokeUserSessions(userId, now) {
    for (const session of this.sessions.values()) {
      if (String(session.userId) === String(userId) && !session.revokedAt) {
        session.revokedAt = new Date(now);
      }
    }
  }

  async insertSession({ userId, tokenHash, expiresAt }) {
    const session = {
      id: this.nextSessionId,
      userId,
      tokenHash,
      expiresAt: new Date(expiresAt),
      revokedAt: null,
    };
    this.nextSessionId += 1;
    this.sessions.set(tokenHash, session);
    return { id: session.id, expiresAt: session.expiresAt.toISOString() };
  }

  async findActiveSession(tokenHash, now) {
    const session = this.sessions.get(tokenHash);
    if (!session || session.revokedAt || session.expiresAt <= now) return null;
    const user = this.users.find((row) => row.id === session.userId);
    if (!user) return null;
    return {
      sessionId: session.id,
      expiresAt: session.expiresAt.toISOString(),
      user: { ...user },
    };
  }

  async revokeSession(tokenHash, now) {
    const session = this.sessions.get(tokenHash);
    if (!session || session.revokedAt || session.expiresAt <= now) return false;
    session.revokedAt = new Date(now);
    return true;
  }

  async transaction(work) {
    const users = this.users.map((user) => ({ ...user }));
    const sessions = new Map(
      [...this.sessions].map(([key, value]) => [key, { ...value }]),
    );
    const nextUserId = this.nextUserId;
    const nextSessionId = this.nextSessionId;
    try {
      return await work(this);
    } catch (error) {
      this.users = users;
      this.sessions = sessions;
      this.nextUserId = nextUserId;
      this.nextSessionId = nextSessionId;
      throw error;
    }
  }
}

function assertPublicRole(role) {
  if (role !== "customer" && role !== "owner") {
    const error = new Error("Refusing to store a non-public role.");
    error.code = "invalid_role";
    throw error;
  }
}

module.exports = { MemoryAuthStore };
