// ===== IMPORTS & SETUP =====
const express = require("express");
const router = express.Router();
const bcrypt = require("bcrypt");

// ==========================================
// 1. USER MANAGEMENT ENDPOINTS
// ==========================================

// GET all users (admin only)
router.get("/users", async (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') {
    return res.status(403).json({ error: "Admin access required" });
  }
  try {
    const result = await req.pool.query(
      "SELECT 
        TO_CHAR(received_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila', 'YYYY-MM-DD') as date, 
        100 as uptime, 
        COUNT(DISTINCT h_id) as "activeDevices"
      FROM final_sensor_events 
      WHERE received_at >= NOW() - INTERVAL '${parseInt(days)} days'
      GROUP BY 1
      ORDER BY 1 ASC
    `;
    const result = await req.pool.query(query);
    res.json({ history: result.rows });
  } catch (err) {
    console.error("Error fetching performance history:", err);
    res.status(500).json({ error: "Error fetching performance history" });
  }
});

// ==========================================
// 4. INCIDENTS & APPROVALS (Standard)
// ==========================================

router.get("/incidents", async (req, res) => {
  // Auth gate removed for local dashboard access

  try {
    const pool = req.pool;
    const { type = "all", device, startDate, endDate, limit = 100 } = req.query;

    let pendingIncidents = [];
    let verifiedIncidents = [];

    // 1. PENDING (Historical Fire Incidents with Duration)
    if (type === "all" || type === "pending") {
      let pendingQuery = `
        SELECT
          hfi.h_id AS device_id,
          to_manila(hfi.incident_timestamp) as start_time,
          to_manila(CASE WHEN hfi.is_active = TRUE THEN NOW() ELSE hfi.last_seen_at END) as last_seen,
          EXTRACT(EPOCH FROM ((CASE WHEN hfi.is_active = TRUE THEN NOW() ELSE hfi.last_seen_at END) - hfi.incident_timestamp)) as duration_seconds,
          LPAD(FLOOR(EXTRACT(EPOCH FROM ((CASE WHEN hfi.is_active = TRUE THEN NOW() ELSE hfi.last_seen_at END) - hfi.incident_timestamp))/3600)::text, 2, '0') || ':' ||
          LPAD(FLOOR(MOD(EXTRACT(EPOCH FROM ((CASE WHEN hfi.is_active = TRUE THEN NOW() ELSE hfi.last_seen_at END) - hfi.incident_timestamp)), 3600)/60)::text, 2, '0') || ':' ||
          LPAD(FLOOR(MOD(EXTRACT(EPOCH FROM ((CASE WHEN hfi.is_active = TRUE THEN NOW() ELSE hfi.last_seen_at END) - hfi.incident_timestamp)), 60))::text, 2, '0') as duration,
          hfi.status AS alert_level,
          CASE WHEN hfi.is_active = TRUE THEN 'ongoing' ELSE 'resolved' END as event_stage,
          NULL AS flame_value,
          NULL AS smoke_value,
          NULL AS temp_value
        FROM historical_fire_incidents hfi
        WHERE hfi.status >= 2
          AND NOT EXISTS (
            SELECT 1 FROM verified_incidents vi
            WHERE vi.device_id = hfi.h_id AND ABS(EXTRACT(EPOCH FROM (vi.timestamp - hfi.incident_timestamp))) < 3600
          )
      `;
      const pendingParams = [];
      let idx = 1;
      
      if (device) { pendingQuery += ` AND hfi.h_id = $${idx++}`; pendingParams.push(device); }
      
      // Timezone-safe filtering
      if (startDate) { 
        pendingQuery += ` AND hfi.incident_timestamp >= ($${idx++}::date AT TIME ZONE 'Asia/Manila')`; 
        pendingParams.push(startDate); 
      }
      if (endDate) { 
        pendingQuery += ` AND hfi.incident_timestamp <= ($${idx++}::date AT TIME ZONE 'Asia/Manila' + INTERVAL '1 day')`; 
        pendingParams.push(endDate); 
      }

      pendingQuery += ` ORDER BY hfi.incident_timestamp DESC LIMIT $${idx}`;
      pendingParams.push(parseInt(limit));

      try {
        const res = await pool.query(pendingQuery, pendingParams);
        pendingIncidents = res.rows;
      } catch (e) { 
        console.error("Pending query error:", e);
        pendingIncidents = []; 
      }
    }

    // 2. VERIFIED (With Consistent Manila Time)
    if (type === "all" || type === "verified") {
      let verifiedQuery = `
        SELECT 
          vi.id, vi.device_id, vi.alert_level, vi.flame_value, vi.smoke_value, vi.temp_value, vi.notes,
          to_manila(vi.timestamp) as timestamp,
          to_manila(vi.verified_at) as verified_at,
          u.username as verified_by_username
        FROM verified_incidents vi
        LEFT JOIN users u ON vi.verified_by = u.id
        WHERE 1=1
      `;
      const verifiedParams = [];
      let idx = 1;
      if (device) { verifiedQuery += ` AND vi.device_id = $${idx++}`; verifiedParams.push(device); }
      
      if (startDate) { 
        verifiedQuery += ` AND vi.timestamp >= ($${idx++}::date AT TIME ZONE 'Asia/Manila')`; 
        verifiedParams.push(startDate); 
      }
      if (endDate) { 
        verifiedQuery += ` AND vi.timestamp <= ($${idx++}::date AT TIME ZONE 'Asia/Manila' + INTERVAL '1 day')`; 
        verifiedParams.push(endDate); 
      }

      verifiedQuery += ` ORDER BY vi.verified_at DESC LIMIT $${idx}`;
      verifiedParams.push(parseInt(limit));

      try {
        const res = await pool.query(verifiedQuery, verifiedParams);
        verifiedIncidents = res.rows;
      } catch (e) { verifiedIncidents = []; }
    }

    res.json({ pending: pendingIncidents, verified: verifiedIncidents });
  } catch (err) {
    res.status(500).json({ error: "Error fetching incidents" });
  }
});

router.post("/incidents/verify", async (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') return res.status(403).json({ error: "Admin access required" });
  const { device_id, timestamp, alert_level, flame_value, smoke_value, temp_value, notes } = req.body;
  if (!device_id || !timestamp || alert_level === undefined) return res.status(400).json({ error: "Fields required" });

  try {
    const result = await req.pool.query(
      `INSERT INTO verified_incidents (device_id, timestamp, alert_level, flame_value, smoke_value, temp_value, verified_by, notes) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [device_id, timestamp, alert_level, flame_value, smoke_value, temp_value, req.session.user.id, notes]
    );
    res.json({ success: true, incident: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: "Error verifying incident" });
  }
});

// OFFICIAL INCIDENTS (BFP)
router.post("/official-incidents", async (req, res) => {
  if (!req.session.user) return res.status(401).json({ error: "Auth required" });
  const { verified_incident_id, device_id, incident_timestamp, alert_level, flame_value, smoke_value, temp_value, incident_type, barangay, city, establishment_type, probable_cause, estimated_damage, responding_units, casualties_injured, casualties_fatalities, narrative_remarks } = req.body;

  try {
    const vRes = await req.pool.query("SELECT verified_by, verified_at FROM verified_incidents WHERE id = $1", [verified_incident_id]);
    if (vRes.rows.length === 0) return res.status(404).json({ error: "Verified incident not found" });

    const result = await req.pool.query(
      `INSERT INTO official_incidents 
       (verified_incident_id, device_id, incident_timestamp, alert_level, flame_value, smoke_value, temp_value, incident_type, barangay, city, establishment_type, probable_cause, estimated_damage, responding_units, casualties_injured, casualties_fatalities, narrative_remarks, verified_by, verified_at, generated_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20) RETURNING *`,
      [verified_incident_id, device_id, incident_timestamp, alert_level, flame_value, smoke_value, temp_value, incident_type, barangay, city, establishment_type, probable_cause, estimated_damage, responding_units, casualties_injured, casualties_fatalities, narrative_remarks, vRes.rows[0].verified_by, vRes.rows[0].verified_at, req.session.user.id]
    );
    res.json({ success: true, record: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: "Error creating official incident" });
  }
});

router.get("/official-incidents", async (req, res) => {
  if (!req.session.user) return res.status(401).json({ error: "Auth required" });
  try {
    const { startDate, endDate, limit = 100 } = req.query;
    let query = `SELECT oi.*, u1.username as verified_by_username, u2.username as generated_by_username FROM official_incidents oi LEFT JOIN users u1 ON oi.verified_by = u1.id LEFT JOIN users u2 ON oi.generated_by = u2.id WHERE 1=1`;
    const params = [];
    let idx = 1;
    if (startDate) { query += ` AND oi.incident_timestamp >= $${idx++}`; params.push(startDate); }
    if (endDate) { query += ` AND oi.incident_timestamp <= $${idx++}`; params.push(endDate); }
    query += ` ORDER BY oi.generated_at DESC LIMIT $${idx}`;
    params.push(parseInt(limit));

    const result = await req.pool.query(query, params);
    res.json({ success: true, records: result.rows });
  } catch (err) {
    res.status(500).json({ error: "Error fetching official incidents" });
  }
});

// EXPORT OFFICIAL INCIDENTS - FIXED TIMEZONE FOR EXCEL
router.get("/official-incidents/export", async (req, res) => {
  if (!req.session.user) return res.status(401).json({ error: "Auth required" });
  try {
    const format = req.query.format || 'csv';
    const { startDate, endDate } = req.query;
    let query = `SELECT oi.id, oi.device_id, oi.incident_timestamp, oi.alert_level, oi.incident_type, oi.barangay, oi.city, oi.probable_cause FROM official_incidents oi WHERE 1=1`;
    const params = [];
    let idx = 1;
    if (startDate) { query += ` AND oi.incident_timestamp >= $${idx++}`; params.push(startDate); }
    if (endDate) { query += ` AND oi.incident_timestamp <= $${idx++}`; params.push(endDate); }
    query += ` ORDER BY oi.generated_at DESC`;

    const result = await req.pool.query(query, params);
    if (!result.rows.length) return res.status(404).json({ error: "No records" });

    const headers = Object.keys(result.rows[0]);
    
    // FIX: Manual conversion of dates to PH time string before CSV generation
    const csvRows = [headers.join(',')];
    
    result.rows.forEach(row => {
      const values = headers.map(h => {
        let val = row[h];
        if (val instanceof Date) {
          val = val.toLocaleString("en-PH", { timeZone: "Asia/Manila" });
        }
        return `"${String(val || '').replace(/"/g, '""')}"`;
      });
      csvRows.push(values.join(','));
    });
    
    if (format === 'excel') res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    else res.setHeader('Content-Type', 'text/csv');
    
    res.setHeader('Content-Disposition', `attachment; filename="incidents_${new Date().toISOString().split('T')[0]}.${format === 'excel' ? 'xlsx' : 'csv'}"`);
    res.send(csvRows.join('\n'));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Export error" });
  }
});

// USER APPROVALS
router.get("/users/pending", async (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') return res.status(403).json({ error: "Admin only" });
  try {
    const result = await req.pool.query("SELECT id, username, email, role, created_at, status FROM users WHERE status = 'pending' ORDER BY created_at DESC");
    res.json(result.rows);
  } catch (e) { res.status(500).json({ error: "Error pending users" }); }
});

router.post("/users/approve", async (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') return res.status(403).json({ error: "Admin only" });
  try {
    const result = await req.pool.query("UPDATE users SET status = 'approved' WHERE id = $1 RETURNING *", [req.body.userId]);
    res.json({ success: true, user: result.rows[0] });
  } catch (e) { res.status(500).json({ error: "Error approving" }); }
});

router.post("/users/reject", async (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') return res.status(403).json({ error: "Admin only" });
  try {
    const result = await req.pool.query("UPDATE users SET status = 'rejected' WHERE id = $1 RETURNING *", [req.body.userId]);
    res.json({ success: true, user: result.rows[0] });
  } catch (e) { res.status(500).json({ error: "Error rejecting" }); }
});

// ==========================================
// 5. DEVICE REGISTRY ENRICHMENT
// ==========================================
router.get("/devices/:id", async (req, res) => {
  // Auth gate removed for local dashboard access
  try {
    const { id } = req.params;
    const result = await req.pool.query("SELECT * FROM device_registry WHERE h_id = $1", [id]);
    
    if (result.rows.length === 0) {
      return res.json({ 
        h_id: id,
        owner_name: "Unregistered Device",
        contact_number: "N/A",
        barangay: "Unknown",
        address_text: "GPS Location Only",
        structure_type: "Unknown"
      });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error("Error fetching device info:", err);
    res.status(500).json({ error: "Error fetching device registry" });
  }
});

module.exports = router;