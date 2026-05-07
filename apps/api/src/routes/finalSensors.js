const express = require("express");
const router = express.Router();

// Auth gate: all routes require a logged-in user
router.use((req, res, next) => {
  if (!req.session || !req.session.user) {
    return res.status(401).json({ error: "Authentication required" });
  }
  next();
});

// GET /api/final-sensors/latest
// Returns the most recent reading per device (or filtered by device/household)
router.get("/latest", async (req, res) => {
  const { deviceId, householdId, limit = 100 } = req.query;

  try {
    let query = `
      SELECT id, h_id, d_id, pos, temp_c, smoke_ppm, status, lat, lon, raw_payload, received_at
      FROM final_sensor_latest
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    if (deviceId) { query += ` AND d_id = $${idx++}`; params.push(deviceId); }
    if (householdId) { query += ` AND h_id = $${idx++}`; params.push(householdId); }

    query += ` ORDER BY received_at DESC LIMIT $${idx}`;
    params.push(parseInt(limit, 10) || 100);

    const result = await req.pool.query(query, params);
    res.json({ rows: result.rows });
  } catch (err) {
    console.error("Error fetching latest final sensor data:", err);
    res.status(500).json({ error: "Error fetching latest final sensor data" });
  }
});

// GET /api/final-sensors/history
// Returns raw event history with optional filters and pagination
router.get("/history", async (req, res) => {
  const { deviceId, householdId, start, end, limit = 200, offset = 0 } = req.query;

  try {
    let query = `
      SELECT id, h_id, d_id, pos, temp_c, smoke_ppm, status, lat, lon, raw_payload, received_at
      FROM final_sensor_events
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    if (deviceId) { query += ` AND d_id = $${idx++}`; params.push(deviceId); }
    if (householdId) { query += ` AND h_id = $${idx++}`; params.push(householdId); }
    if (start) { query += ` AND received_at >= $${idx++}::timestamptz`; params.push(start); }
    if (end) { query += ` AND received_at <= $${idx++}::timestamptz`; params.push(end); }

    query += ` ORDER BY received_at DESC LIMIT $${idx++} OFFSET $${idx}`;
    params.push(parseInt(limit, 10) || 200);
    params.push(parseInt(offset, 10) || 0);

    const result = await req.pool.query(query, params);
    res.json({ rows: result.rows });
  } catch (err) {
    console.error("Error fetching final sensor history:", err);
    res.status(500).json({ error: "Error fetching final sensor history" });
  }
});

// POST /api/final-sensors/events
// Optional HTTP ingress to store a final sensor payload (admin only to avoid abuse)
router.post("/events", async (req, res) => {
  if (!req.session.user || req.session.user.role !== "admin") {
    return res.status(403).json({ error: "Admin access required" });
  }

  const payload = req.body || {};
  const mapped = mapPayload(payload);

  if (!mapped.h_id || !mapped.d_id) {
    return res.status(400).json({ error: "h_id and d_id are required in payload" });
  }

  try {
    const insertQuery = `
      INSERT INTO final_sensor_events (h_id, d_id, pos, temp_c, smoke_ppm, status, lat, lon, raw_payload)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id, received_at
    `;

    const params = [
      mapped.h_id,
      mapped.d_id,
      mapped.pos,
      mapped.temp_c,
      mapped.smoke_ppm,
      mapped.status,
      mapped.lat,
      mapped.lon,
      JSON.stringify(payload)
    ];

    const result = await req.pool.query(insertQuery, params);
    res.json({ success: true, event: { id: result.rows[0].id, received_at: result.rows[0].received_at } });
  } catch (err) {
    console.error("Error ingesting final sensor payload:", err);
    res.status(500).json({ error: "Error ingesting final sensor payload" });
  }
});

function mapPayload(payload) {
  const env = payload.env || {};
  const log = payload.log || {};
  const loc = Array.isArray(payload.loc) ? payload.loc : [];

  const lat = loc.length >= 1 ? loc[0] : null;
  const lon = loc.length >= 2 ? loc[1] : null;

  return {
    h_id: payload.h_id,
    d_id: payload.d_id,
    pos: payload.pos,
    temp_c: env.t,
    smoke_ppm: env.s,
    status: log.st,
    lat,
    lon,
  };
}

module.exports = router;

