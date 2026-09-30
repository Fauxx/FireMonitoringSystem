const express = require('express');
const router = express.Router();
const { InfluxDB } = require('@influxdata/influxdb-client');

const url = process.env.INFLUXDB_URL || 'http://influx:8086';
const token = process.env.INFLUXDB_TOKEN;
const org = process.env.INFLUXDB_ORG || 'fire-monitoring';
const bucket = process.env.INFLUXDB_BUCKET || 'sensor-data';

// Auth gate removed for local dashboard access

// GET /api/telemetry/history
router.get('/history', async (req, res) => {
    const { h_id, minutes = 30 } = req.query;

    if (!token) {
        return res.status(500).json({ error: "INFLUXDB_TOKEN is not configured." });
    }

    if (!h_id) {
        return res.status(400).json({ error: "h_id query parameter is required." });
    }

    try {
        const client = new InfluxDB({ url, token });
        const queryApi = client.getQueryApi(org);

        // Fetch the last X minutes for the specific node and pivot the fields
        const fluxQuery = `
            from(bucket: "${bucket}")
            |> range(start: -${parseInt(minutes, 10)}m)
            |> filter(fn: (r) => r["_measurement"] == "node_telemetry" or r["_measurement"] == "fire_data")
            |> filter(fn: (r) => r["h_id"] == "${h_id}")
            |> pivot(rowKey: ["_time", "h_id"], columnKey: ["_field"], valueColumn: "_value")
            |> keep(columns: ["_time", "h_id", "status", "temp", "smoke", "flame"])
            |> sort(columns: ["_time"])
        `;

        const rows = [];
        queryApi.queryRows(fluxQuery, {
            next: (row, tableMeta) => {
                const o = tableMeta.toObject(row);
                rows.push({
                    time: o._time,
                    h_id: o.h_id,
                    status: o.status,
                    temp: o.temp,
                    smoke: o.smoke,
                    flame: o.flame
                });
            },
            error: (error) => {
                console.error("InfluxDB Query Error:", error);
                res.status(500).json({ error: "Failed to query telemetry history." });
            },
            complete: () => {
                res.json({ data: rows });
            }
        });
    } catch (err) {
        console.error("Error setting up InfluxDB query:", err);
        res.status(500).json({ error: "Internal server error" });
    }
});

module.exports = router;
