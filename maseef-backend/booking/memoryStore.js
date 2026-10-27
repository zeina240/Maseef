class MemoryBookingStore {
  constructor() {
    this.profiles = new Map();
    this.dates = new Map();
    this.requests = new Map();
    this.nextId = 1;
    this.locks = new Map();
  }

  async withLock(key, work) {
    const previous = this.locks.get(key) ?? Promise.resolve();
    let release;
    const gate = new Promise((resolve) => {
      release = resolve;
    });
    this.locks.set(key, previous.then(() => gate));
    await previous;
    try {
      return await work();
    } finally {
      release();
    }
  }

  async getProfile(listingKey) {
    const profile = this.profiles.get(listingKey);
    return profile ? structuredClone(profile) : null;
  }

  async putProfile(profile) {
    this.profiles.set(profile.listingKey, structuredClone(profile));
    return structuredClone(profile);
  }

  async listDates(listingKey, from, to) {
    return [...this.dates.values()]
      .filter((row) => row.listingKey === listingKey && row.date >= from && row.date <= to)
      .map((row) => structuredClone(row));
  }

  async getDate(listingKey, date) {
    const row = this.dates.get(`${listingKey}|${date}`);
    return row ? structuredClone(row) : null;
  }

  async putDate(row) {
    this.dates.set(`${row.listingKey}|${row.date}`, structuredClone(row));
    return structuredClone(row);
  }

  async listBlockingRequests(listingKey, from, to) {
    return [...this.requests.values()]
      .filter((request) => (
        request.listingKey === listingKey &&
        request.stayDate >= from &&
        request.stayDate <= to &&
        (request.status === "pending" || request.status === "confirmed")
      ))
      .map((request) => structuredClone(request));
  }

  async listRequestsForCustomer(customerUserId) {
    return [...this.requests.values()]
      .filter((request) => request.customerUserId === customerUserId)
      .map((request) => structuredClone(request));
  }

  async listRequestsForOwner(ownerUserId) {
    const keys = new Set(
      [...this.profiles.values()]
        .filter((profile) => profile.ownerUserId === ownerUserId)
        .map((profile) => profile.listingKey),
    );
    return [...this.requests.values()]
      .filter((request) => keys.has(request.listingKey))
      .map((request) => structuredClone(request));
  }

  async getRequest(id) {
    const request = this.requests.get(id);
    return request ? structuredClone(request) : null;
  }

  async insertRequest(request) {
    const id = this.nextId;
    this.nextId += 1;
    const stored = { ...request, id };
    this.requests.set(id, stored);
    return structuredClone(stored);
  }

  async updateRequest(request) {
    this.requests.set(request.id, structuredClone(request));
    return structuredClone(request);
  }
}

module.exports = { MemoryBookingStore };
