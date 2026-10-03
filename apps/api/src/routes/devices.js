const express = require("express");
const router = express.Router();

router.get("/", async (req, res) => {
  try {
    const result = await req.pool.query("SELECT h_id, lat, lon, owner_name, barangay FROM device_registry ORDER BY h_id ASC");
    res.json({ rows: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

module.exports = router;
