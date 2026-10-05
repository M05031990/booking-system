const farePerKm = 1.0;

/// 1 km radius = 2 km across.
const riderSearchRadiusKm = 1.0;

/// Distance at which the rider counts as arrived.
const arrivalRadiusMeters = 50.0;

/// Minimum gap between live location writes.
const locationWriteInterval = Duration(seconds: 3);
