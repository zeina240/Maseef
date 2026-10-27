class BookingError extends Error {
  constructor(code, message, status = 400) {
    super(message);
    this.name = "BookingError";
    this.code = code;
    this.status = status;
  }
}

function toPublicAvailabilityError(error) {
  if (error && (error.code === "42P01" || error.code === "3F000")) {
    return {
      httpStatus: 200,
      body: {
        status: "success",
        data: {
          configured: false,
          reason: "storage_not_ready",
          days: [],
        },
      },
    };
  }

  if (error instanceof BookingError) {
    return {
      httpStatus: error.status,
      body: {
        status: "error",
        code: error.code,
        message: error.message,
      },
    };
  }

  return {
    httpStatus: 500,
    body: {
      status: "error",
      code: "internal_error",
      message: "Failed to load availability.",
    },
  };
}

module.exports = { BookingError, toPublicAvailabilityError };
