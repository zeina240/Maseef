# MASEEF booking API

This describes the session booking model. The SQL file
`migrations/001_session_bookings.sql` has not been executed. Do not run it
until it is explicitly approved.

Customer and owner accounts are not implemented. `server.js` mounts only the
two public read routes. Management routes exist in `booking/routes.js` and
refuse to be constructed unless an authenticate function is passed. The running
app does not pass one.

## Status values

`pending`, `confirmed`, `rejected`, and `cancelled`.

A request is pending until the linked owner accepts or rejects it. Submitting
a request does not confirm it. Rejected and cancelled requests do not block
the date. There is no automatic expiry time, because none was supplied.

The older `bookings` table is unchanged and still uses
`pending`, `confirmed`, `cancelled`, and `completed` for night ranges.

## Public reads

These are mounted.

### `GET /api/listings/:listingKey/booking`

No profile:

```json
{
  "status": "success",
  "data": {
    "configured": false,
    "reason": "not_configured",
    "listingKey": "hareem-sultan"
  }
}
```

Profile exists:

```json
{
  "status": "success",
  "data": {
    "configured": true,
    "reason": "configured",
    "listingKey": "hareem-sultan",
    "offersFullDay": true,
    "offersSessions": true,
    "fullDay": { "start": "08:00", "end": "22:00" },
    "morning": { "start": "08:00", "end": "13:00" },
    "evening": { "start": "14:00", "end": "22:00" },
    "prices": { "fullDay": null, "morning": null, "evening": null },
    "overnightSessionsSupported": false
  }
}
```

Prices are null unless that owner saved a number. The response does not include
the owner id.

### `GET /api/listings/:listingKey/availability?year=2026&month=10`

Without a profile, `configured` is false and `days` is empty. The app shows
“Availability not yet provided” and does not invent booked dates.

With a profile, every day of the month is returned:

| `state` | Meaning |
| --- | --- |
| `available` | Every offered mode is open |
| `partial` | One session is taken and another is still open |
| `pending` | Offered modes are pending or booked, and at least one is pending |
| `booked` | Offered modes are confirmed |
| `closed` | The owner closed that date |
| `unavailable` | The owner has not opened that date |

Each offered mode is `available`, `pending`, or `booked`, with the owner’s
`start`, `end`, and optional `price`.

If the new tables are not in the database yet, a read responds with
`reason: "storage_not_ready"` instead of a server error. That still means the
calendar must not show sample dates.

Validation errors use HTTP 400:

```json
{ "status": "error", "code": "invalid_date", "message": "month must be a number from 1 to 12." }
```

`invalid_listing` is the same shape for a bad chalet id.

## Management routes

Not mounted. They require a real authenticated `req.user` with `id` and
`role`. Until sign-in exists, there is no honest way to know which user is
calling.

| Method and path | Who | Action |
| --- | --- | --- |
| `POST /api/listings/:listingKey/booking-requests` | customer | Create a pending request |
| `GET /api/me/booking-requests` | customer | List that customer’s requests |
| `POST /api/me/booking-requests/:id/cancel` | customer | Cancel the customer’s own pending request |
| `GET /api/owner/listings/:listingKey/booking-requests` | linked owner | List requests for that chalet |
| `POST /api/owner/booking-requests/:id/accept` | linked owner | Confirm, after rechecking the slot |
| `POST /api/owner/booking-requests/:id/reject` | linked owner | Reject and release the slot |
| `PUT /api/owner/listings/:listingKey/booking` | linked owner | Replace the booking rules |
| `PUT /api/owner/listings/:listingKey/availability` | linked owner | Open, close, or override dates |

Create request:

```json
{ "stayDate": "2026-11-02", "mode": "morning" }
```

The server copies the start, end, and price from the owner’s schedule. A
customer cannot send a status, a price, or a time. The response is HTTP 201
and `data.status` is `pending`, plus a `reference` such as `MS-1A2B3C4D`.

Owner schedule:

```json
{
  "offersFullDay": true,
  "offersSessions": true,
  "fullDayCheckIn": "08:00",
  "fullDayCheckOut": "22:00",
  "morningStart": "08:00",
  "morningEnd": "13:00",
  "eveningStart": "14:00",
  "eveningEnd": "22:00",
  "morningPrice": 150
}
```

Omitted prices stay null. `18:00` to `02:00` is rejected with
`overnight_not_supported`. Overlapping morning and evening windows are
rejected with `overlapping_windows`. A start that is not before the end is
`invalid_time_range`.

Date update:

```json
{
  "dates": [
    { "date": "2026-11-02", "closed": false },
    { "date": "2026-11-03", "closed": true },
    {
      "date": "2026-11-04",
      "closed": false,
      "eveningStart": "16:00",
      "eveningEnd": "22:00",
      "eveningPrice": 200
    }
  ]
}
```

A missing date row means that date is not open. `closed: true` is a closure.
Null mode or time fields inherit the chalet schedule.

## Conflict rules

Checked again inside a per-date lock when a request is created and when it is
confirmed:

- A full-day request conflicts with every morning and evening request on that
  date, even when the clock times would not otherwise overlap.
- Morning and evening requests can both exist when the schedule offers both
  and the half-open windows do not overlap. `08:00–13:00` and `13:00–22:00`
  can share a date. `08:00–16:00` and `15:00–22:00` cannot.
- Pending and confirmed requests block. Rejected and cancelled requests do
  not.
- Two creates for the same slot: one is stored as pending and the other
  receives `slot_conflict`.
- If a confirmed reservation already has the slot, accepting another request
  receives `slot_conflict` and leaves that request pending.
- If two conflicting pending requests are accepted together, one becomes
  confirmed and the other is rejected in the same lock so it does not keep
  the date closed.
- Past dates, using the `Asia/Hebron` calendar, are `invalid_date`.

The migration’s `listing_date_guards` row is what a future database
transaction locks with `SELECT ... FOR UPDATE`. The GiST exclusion constraint
`booking_requests_no_overlap` rejects overlapping pending or confirmed ranges
even if the application check is skipped. Full-day rows block
`[stay_date, next day)`. Session rows block their real clock window. Rejected
and cancelled rows store a null block and drop out of the constraint.

## Authorization errors

| Code | HTTP | When |
| --- | --- | --- |
| `authentication_not_configured` | 401 | No signed-in user |
| `forbidden` | 403 | Customer calling an owner action, or a different owner |
| `owner_not_linked` | 403 | The chalet profile has no real `users.id` yet |
| `availability_not_configured` | 409 | No schedule profile |
| `date_closed` | 409 | Owner closure |
| `date_unavailable` | 409 | Date was not opened |
| `mode_not_offered` | 409 | That mode is off for the date |
| `slot_conflict` | 409 | The slot is already held |
| `request_not_pending` | 409 | The request was already decided |
| `not_found` | 404 | Unknown request id |

## What is still required before real use

1. Approve and run `migrations/001_session_bookings.sql`. It needs permission
   to create `btree_gist`.
2. Add real customer and owner sign-in that sets `req.user.id` from `users.id`.
3. Link each chalet by inserting a `listing_booking_profiles` row whose
   `owner_user_id` is that owner’s real user id. No seed script does this.
4. Let that owner save times and the specific dates that are open.
5. Only then mount `createProtectedBookingRouter`.
