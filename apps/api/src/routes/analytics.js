const express = require('express');
const router = express.Router();
const { ensureAuthenticated } = require('../middleware/auth');

router.use(ensureAuthenticated);

// GET analytics data
// /api/analytics?m=081925BR98-1&start=2025-11-01&end=2025-11-20
router.get('/', async (req, res) => {
    const pool = req.pool;
    const deviceId = req.query.m || req.query.h_id || req.query.device;
    const start = req.query.start;
    const end = req.query.end;

    const params = [];
    const whereClauses = [];

    if (deviceId) {
        params.push(deviceId);
        whereClauses.push(`h_id = $${params.length}`);
    }
    if (start) {
        params.push(start);
        whereClauses.push(`timestamp_window >= $${params.length}::timestamptz`);
    }
    if (end) {
        params.push(end);
        whereClauses.push(`timestamp_window <= $${params.length}::timestamptz`);
    }

    const where = whereClauses.length ? 'WHERE ' + whereClauses.join(' AND ') : '';

    const query = `
        SELECT h_id, h_id as m, timestamp_window, fa, fb, ga, gb, sa, sb, ta, tb, la, lo, alert_level
        FROM sensor_data_aggregated
        ${where}
        ORDER BY timestamp_window ASC
        LIMIT 500
    `;


    try {
        const result = await pool.query(query, params);
        console.log(`Analytics query rows: ${result.rows.length}`);
        res.json({ rows: result.rows });
    } catch (err) {
        console.error("Analytics query error:", err);
        return res.status(500).json({ error: err.message });
    }
});

// GET distinct devices for dropdown
router.get('/devices', async (req, res) => {
    const pool = req.pool;
    try {
        const result = await pool.query(`
            SELECT DISTINCT h_id FROM (
                SELECT h_id FROM device_registry
                UNION
                SELECT h_id FROM final_sensor_events
            ) all_devs WHERE h_id IS NOT NULL ORDER BY h_id ASC
        `);
        const rows = result.rows.map(r => ({ h_id: r.h_id, m: r.h_id }));
        res.json({ devices: rows.map(r => r.h_id), rows });
    } catch (err) {
        console.error("Error fetching devices:", err);
        return res.status(500).json({ error: err.message });
    }
});

// GET heatmap data - incident alerts by day
router.get('/heatmap', async (req, res) => {

    const pool = req.pool;
    const { days = 365, type = 'system', device: queryDevice, h_id, m, start, end, startDate, endDate } = req.query;
    const device = queryDevice || h_id || m;
    const effectiveStart = start || startDate;
    const effectiveEnd = end || endDate;

    try {
        let query;
        const params = [];
        let paramIndex = 1;
        
        if (type === 'verified') {
            // Get verified incidents from historical_fire_incidents
            query = `
                SELECT 
                    to_char(incident_timestamp, 'YYYY-MM-DD') as date,
                    COUNT(*) as count,
                    MAX(status) as max_level,
                    COUNT(CASE WHEN status >= 2 THEN 1 END) as critical_count,
                    COUNT(CASE WHEN status = 1 THEN 1 END) as warning_count
                FROM historical_fire_incidents
                WHERE 1=1
            `;
            
            if (device) {
                query += ` AND h_id = $${paramIndex}`;
                params.push(device);
                paramIndex++;
            }
            if (effectiveStart) {
                query += ` AND incident_timestamp >= $${paramIndex}::timestamptz`;
                params.push(effectiveStart);
                paramIndex++;
            } else if (days) {
                query += ` AND incident_timestamp >= NOW() - INTERVAL '${parseInt(days)} days'`;
            }
            if (effectiveEnd) {
                query += ` AND incident_timestamp <= $${paramIndex}::timestamptz`;
                params.push(effectiveEnd);
                paramIndex++;
            }
            
            query += ` GROUP BY to_char(incident_timestamp, 'YYYY-MM-DD') ORDER BY date ASC`;
        } else {
            // Get system-generated incidents (from final_sensor_events)
            query = `
                SELECT 
                    to_char(received_at, 'YYYY-MM-DD') as date,
                    COUNT(*) as count,
                    MAX(status) as max_level,
                    COUNT(CASE WHEN status = 2 THEN 1 END) as critical_count,
                    COUNT(CASE WHEN status = 1 THEN 1 END) as warning_count
                FROM final_sensor_events
                WHERE status >= 1
            `;
            
            if (device) {
                query += ` AND h_id = $${paramIndex}`;
                params.push(device);
                paramIndex++;
            }
            if (effectiveStart) {
                query += ` AND received_at >= $${paramIndex}::timestamptz`;
                params.push(effectiveStart);
                paramIndex++;
            } else if (days) {
                query += ` AND received_at >= NOW() - INTERVAL '${parseInt(days)} days'`;
            }
            if (effectiveEnd) {
                query += ` AND received_at <= $${paramIndex}::timestamptz`;
                params.push(effectiveEnd);
                paramIndex++;
            }
            
            query += ` GROUP BY to_char(received_at, 'YYYY-MM-DD') ORDER BY date ASC`;
        }

        const result = await pool.query(query, params.length > 0 ? params : undefined);
        
        // Convert to object for easy lookup
        const heatmapData = {};
        result.rows.forEach(row => {
            heatmapData[row.date] = {
                count: parseInt(row.count),
                maxLevel: parseInt(row.max_level),
                critical: parseInt(row.critical_count),
                warning: parseInt(row.warning_count)
            };
        });

        res.json({ heatmap: heatmapData });
    } catch (err) {
        console.error("Error fetching heatmap data:", err);
        // Fallback to empty if error
        res.json({ heatmap: {} });
    }
});

// GET incident metrics - system-generated vs verified (with filters)
router.get('/incident-metrics', async (req, res) => {
    const pool = req.pool;
    const { days = 30, device: queryDevice, h_id, m, start, end, startDate, endDate } = req.query;
    const device = queryDevice || h_id || m;
    const effectiveStart = start || startDate;
    const effectiveEnd = end || endDate;

    try {
        // Build WHERE clauses for filters
        const systemWhere = ['status >= 1'];
        const verifiedWhere = ['1=1'];
        const systemParams = [];
        const verifiedParams = [];
        let systemParamIndex = 1;
        let verifiedParamIndex = 1;

        // Date filter
        if (effectiveStart && effectiveEnd) {
            systemWhere.push(`received_at >= $${systemParamIndex}::timestamptz AND received_at <= $${systemParamIndex + 1}::timestamptz`);
            systemParams.push(effectiveStart, effectiveEnd);
            systemParamIndex += 2;
            
            verifiedWhere.push(`incident_timestamp >= $${verifiedParamIndex}::timestamptz AND incident_timestamp <= $${verifiedParamIndex + 1}::timestamptz`);
            verifiedParams.push(effectiveStart, effectiveEnd);
            verifiedParamIndex += 2;
        } else if (days) {
            systemWhere.push(`received_at >= NOW() - INTERVAL '${parseInt(days)} days'`);
            verifiedWhere.push(`incident_timestamp >= NOW() - INTERVAL '${parseInt(days)} days'`);
        }

        // Device filter
        if (device) {
            systemWhere.push(`h_id = $${systemParamIndex}`);
            systemParams.push(device);
            systemParamIndex++;
            
            verifiedWhere.push(`h_id = $${verifiedParamIndex}`);
            verifiedParams.push(device);
            verifiedParamIndex++;
        }

        const systemWhereClause = 'WHERE ' + systemWhere.join(' AND ');
        const verifiedWhereClause = 'WHERE ' + verifiedWhere.join(' AND ');

        // System-generated incidents (from final_sensor_events)
        const systemGeneratedQuery = `
            SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN status = 2 THEN 1 END) as critical,
                COUNT(CASE WHEN status = 1 THEN 1 END) as warning
            FROM final_sensor_events
            ${systemWhereClause}
        `;

        // Verified incidents (from historical_fire_incidents)
        const verifiedQuery = `
            SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN status >= 2 THEN 1 END) as critical,
                COUNT(CASE WHEN status = 1 THEN 1 END) as warning
            FROM historical_fire_incidents
            ${verifiedWhereClause}
        `;

        const [systemResult, verifiedResult] = await Promise.all([
            pool.query(systemGeneratedQuery, systemParams.length > 0 ? systemParams : undefined).catch(e => { console.error("Sys gen query err:", e); return { rows: [{ total: 0, critical: 0, warning: 0 }] }; }),
            pool.query(verifiedQuery, verifiedParams.length > 0 ? verifiedParams : undefined).catch(e => { console.error("Verified query err:", e); return { rows: [{ total: 0, critical: 0, warning: 0 }] }; })
        ]);

        const systemGenerated = systemResult.rows[0] || { total: 0, critical: 0, warning: 0 };
        const verified = verifiedResult.rows[0] || { total: 0, critical: 0, warning: 0 };
        const sysTotal = parseInt(systemGenerated.total, 10) || 0;
        const verTotal = parseInt(verified.total, 10) || 0;

        res.json({
            systemGenerated: {
                total: sysTotal,
                critical: parseInt(systemGenerated.critical, 10) || 0,
                warning: parseInt(systemGenerated.warning, 10) || 0
            },
            verified: {
                total: verTotal,
                critical: parseInt(verified.critical, 10) || 0,
                warning: parseInt(verified.warning, 10) || 0
            },
            verificationRate: sysTotal > 0 
                ? ((verTotal / sysTotal) * 100).toFixed(1)
                : (verTotal > 0 ? 100.0 : 0.0)
        });
    } catch (err) {
        console.error("Error fetching incident metrics:", err);
        res.json({
            systemGenerated: { total: 0, critical: 0, warning: 0 },
            verified: { total: 0, critical: 0, warning: 0 },
            verificationRate: 0
        });
    }
});

// GET system performance data
router.get('/performance', async (req, res) => {

    const pool = req.pool;
    const { days = 30, start, end } = req.query;

    try {
        // Build WHERE clause for date filtering
        let whereClause = '';
        const params = [];
        let paramIndex = 1;
        
        if (start && end) {
            whereClause = `WHERE timestamp >= $${paramIndex}::timestamp AND timestamp <= $${paramIndex + 1}::timestamp`;
            params.push(start, end);
        } else {
            whereClause = `WHERE timestamp >= NOW() - INTERVAL '${parseInt(days)} days'`;
        }
        
        // Get system metrics history
        const metricsQuery = `
            SELECT 
                DATE(received_at) as date,
                100 as avg_uptime,
                COUNT(DISTINCT h_id) as avg_active_devices,
                COUNT(DISTINCT h_id) as max_active_devices,
                COUNT(DISTINCT h_id) as min_active_devices,
                10 as avg_locations
            FROM final_sensor_events
            ${whereClause.replace('timestamp', 'received_at')}
            GROUP BY DATE(received_at)
            ORDER BY date ASC
        `;

        const [metricsResult] = await Promise.all([
            pool.query(metricsQuery, params.length > 0 ? params : undefined).catch(() => ({ rows: [] }))
        ]);

        let currentMetrics = null;
        if (!currentMetrics) {
            const activeDevicesResult = await pool.query(
                `SELECT COUNT(DISTINCT h_id) as count 
                 FROM final_sensor_events 
                 WHERE received_at > NOW() - INTERVAL '24 hours'`
            );
            const totalDevicesResult = await pool.query(
                `SELECT COUNT(h_id) as count FROM device_registry`
            );
            const activeDevices = parseInt(activeDevicesResult.rows[0]?.count || 0);
            const totalDevices = parseInt(totalDevicesResult.rows[0]?.count || 1);
            const uptime = totalDevices > 0 ? ((activeDevices / totalDevices) * 100) : 0;

            const locationsResult = await pool.query(
                `SELECT COUNT(DISTINCT barangay) as count FROM device_registry WHERE barangay IS NOT NULL`
            );
            const totalLocations = parseInt(locationsResult.rows[0]?.count || 0);

            currentMetrics = {
                system_uptime: uptime,
                active_devices: activeDevices,
                total_locations: totalLocations
            };
        }

        res.json({
            history: metricsResult.rows.map(row => ({
                date: row.date,
                uptime: parseFloat(row.avg_uptime || 0),
                activeDevices: parseFloat(row.avg_active_devices || 0),
                maxDevices: parseInt(row.max_active_devices || 0),
                minDevices: parseInt(row.min_active_devices || 0),
                locations: parseFloat(row.avg_locations || 0)
            })),
            current: {
                uptime: parseFloat(currentMetrics.system_uptime || 0),
                activeDevices: parseInt(currentMetrics.active_devices || 0),
                totalLocations: parseInt(currentMetrics.total_locations || 0)
            }
        });
    } catch (err) {
        console.error("Error fetching performance data:", err);
        res.json({
            history: [],
            current: { uptime: 0, activeDevices: 0, totalLocations: 0 }
        });
    }
});

module.exports = router;
