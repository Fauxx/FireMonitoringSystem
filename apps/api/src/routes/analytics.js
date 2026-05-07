const express = require('express');
const router = express.Router();

// GET analytics data
// /api/analytics?m=081925BR98-1&start=2025-11-01&end=2025-11-20
router.get('/', async (req, res) => {
    const pool = req.pool;
    const deviceId = req.query.m;
    const start = req.query.start;
    const end = req.query.end;

    const params = [];
    const whereClauses = [];

    if (deviceId) {
        params.push(deviceId);
        whereClauses.push(`m = $${params.length}`);
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
        SELECT m, timestamp_window, fa, fb, ga, gb, sa, sb, ta, tb, la, lo, alert_level
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
        const result = await pool.query(`SELECT DISTINCT m FROM sensor_data_aggregated WHERE m IS NOT NULL ORDER BY m`);
        res.json({ devices: result.rows.map(r => r.m) });
    } catch (err) {
        console.error("Error fetching devices:", err);
        return res.status(500).json({ error: err.message });
    }
});

// GET heatmap data - incident alerts by day
router.get('/heatmap', async (req, res) => {
    if (!req.session || !req.session.user) {
        return res.status(401).json({ error: "Authentication required" });
    }
    
    const pool = req.pool;
    const { days = 365, type = 'system', device, start, end } = req.query;

    try {
        let query;
        const params = [];
        let paramIndex = 1;
        
        if (type === 'verified') {
            // Get verified incidents
            query = `
                SELECT 
                    DATE(timestamp) as date,
                    COUNT(*) as count,
                    MAX(alert_level) as max_level,
                    COUNT(CASE WHEN alert_level >= 3 THEN 1 END) as critical_count,
                    COUNT(CASE WHEN alert_level = 2 THEN 1 END) as warning_count
                FROM verified_incidents
                WHERE timestamp >= NOW() - INTERVAL '${parseInt(days)} days'
                    AND alert_level >= 2
            `;
            
            if (device) {
                query += ` AND device_id = $${paramIndex}`;
                params.push(device);
                paramIndex++;
            }
            if (start) {
                query += ` AND timestamp >= $${paramIndex}`;
                params.push(start);
                paramIndex++;
            }
            if (end) {
                query += ` AND timestamp <= $${paramIndex}`;
                params.push(end);
                paramIndex++;
            }
            
            query += ` GROUP BY DATE(timestamp) ORDER BY date ASC`;
        } else {
            // Get system-generated incidents (from incident_alerts)
            query = `
                SELECT 
                    DATE(time) as date,
                    COUNT(*) as count,
                    MAX(alert_level) as max_level,
                    COUNT(CASE WHEN alert_level >= 3 THEN 1 END) as critical_count,
                    COUNT(CASE WHEN alert_level = 2 THEN 1 END) as warning_count
                FROM incident_alerts
                WHERE time >= NOW() - INTERVAL '${parseInt(days)} days'
                    AND alert_level >= 2
            `;
            
            if (device) {
                query += ` AND m = $${paramIndex}`;
                params.push(device);
                paramIndex++;
            }
            if (start) {
                query += ` AND time >= $${paramIndex}`;
                params.push(start);
                paramIndex++;
            }
            if (end) {
                query += ` AND time <= $${paramIndex}`;
                params.push(end);
                paramIndex++;
            }
            
            query += ` GROUP BY DATE(time) ORDER BY date ASC`;
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
        // Fallback to empty if tables don't exist
        res.json({ heatmap: {} });
    }
});

// GET incident metrics - system-generated vs verified (with filters)
router.get('/incident-metrics', async (req, res) => {
    if (!req.session || !req.session.user) {
        return res.status(401).json({ error: "Authentication required" });
    }
    
    const pool = req.pool;
    const { days = 30, device, start, end } = req.query;

    try {
        // Build WHERE clauses for filters
        const systemWhere = [];
        const verifiedWhere = [];
        const systemParams = [];
        const verifiedParams = [];
        let systemParamIndex = 1;
        let verifiedParamIndex = 1;

        // Date filter
        if (start && end) {
            systemWhere.push(`time >= $${systemParamIndex} AND time <= $${systemParamIndex + 1}`);
            systemParams.push(start, end);
            systemParamIndex += 2;
            
            verifiedWhere.push(`timestamp >= $${verifiedParamIndex} AND timestamp <= $${verifiedParamIndex + 1}`);
            verifiedParams.push(start, end);
            verifiedParamIndex += 2;
        } else {
            systemWhere.push(`time >= NOW() - INTERVAL '${parseInt(days)} days'`);
            verifiedWhere.push(`created_at >= NOW() - INTERVAL '${parseInt(days)} days'`);
        }

        // Device filter
        if (device) {
            systemWhere.push(`m = $${systemParamIndex}`);
            systemParams.push(device);
            systemParamIndex++;
            
            verifiedWhere.push(`device_id = $${verifiedParamIndex}`);
            verifiedParams.push(device);
            verifiedParamIndex++;
        }

        const systemWhereClause = systemWhere.length > 0 ? 'WHERE ' + systemWhere.join(' AND ') + ' AND alert_level >= 2' : 'WHERE alert_level >= 2';
        const verifiedWhereClause = verifiedWhere.length > 0 ? 'WHERE ' + verifiedWhere.join(' AND ') + ' AND alert_level >= 2' : 'WHERE alert_level >= 2';

        // System-generated incidents (from incident_alerts)
        const systemGeneratedQuery = `
            SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN alert_level >= 3 THEN 1 END) as critical,
                COUNT(CASE WHEN alert_level = 2 THEN 1 END) as warning
            FROM incident_alerts
            ${systemWhereClause}
        `;

        // Verified incidents
        const verifiedQuery = `
            SELECT 
                COUNT(*) as total,
                COUNT(CASE WHEN alert_level >= 3 THEN 1 END) as critical,
                COUNT(CASE WHEN alert_level = 2 THEN 1 END) as warning
            FROM verified_incidents
            ${verifiedWhereClause}
        `;

        const [systemResult, verifiedResult] = await Promise.all([
            pool.query(systemGeneratedQuery, systemParams.length > 0 ? systemParams : undefined).catch(() => ({ rows: [{ total: 0, critical: 0, warning: 0 }] })),
            pool.query(verifiedQuery, verifiedParams.length > 0 ? verifiedParams : undefined).catch(() => ({ rows: [{ total: 0, critical: 0, warning: 0 }] }))
        ]);

        const systemGenerated = systemResult.rows[0] || { total: 0, critical: 0, warning: 0 };
        const verified = verifiedResult.rows[0] || { total: 0, critical: 0, warning: 0 };

        res.json({
            systemGenerated: {
                total: parseInt(systemGenerated.total),
                critical: parseInt(systemGenerated.critical),
                warning: parseInt(systemGenerated.warning)
            },
            verified: {
                total: parseInt(verified.total),
                critical: parseInt(verified.critical),
                warning: parseInt(verified.warning)
            },
            verificationRate: systemGenerated.total > 0 
                ? ((verified.total / systemGenerated.total) * 100).toFixed(1)
                : 0
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
    if (!req.session || !req.session.user) {
        return res.status(401).json({ error: "Authentication required" });
    }
    
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
                DATE(timestamp) as date,
                AVG(system_uptime) as avg_uptime,
                AVG(active_devices) as avg_active_devices,
                MAX(active_devices) as max_active_devices,
                MIN(active_devices) as min_active_devices,
                AVG(total_locations) as avg_locations
            FROM system_metrics
            ${whereClause}
            GROUP BY DATE(timestamp)
            ORDER BY date ASC
        `;

        // Get current metrics
        const currentQuery = `
            SELECT 
                system_uptime,
                active_devices,
                total_locations,
                timestamp
            FROM system_metrics
            ORDER BY timestamp DESC
            LIMIT 1
        `;

        const [metricsResult, currentResult] = await Promise.all([
            pool.query(metricsQuery, params.length > 0 ? params : undefined).catch(() => ({ rows: [] })),
            pool.query(currentQuery).catch(() => ({ rows: [] }))
        ]);

        // Fallback calculation if system_metrics is empty
        let currentMetrics = currentResult.rows[0] || null;
        if (!currentMetrics) {
            const activeDevicesResult = await pool.query(
                `SELECT COUNT(DISTINCT m) as count 
                 FROM sensor_data_aggregated 
                 WHERE timestamp_window > NOW() - INTERVAL '24 hours'`
            );
            const totalDevicesResult = await pool.query(
                `SELECT COUNT(DISTINCT m) as count FROM sensor_data_aggregated`
            );
            const activeDevices = parseInt(activeDevicesResult.rows[0]?.count || 0);
            const totalDevices = parseInt(totalDevicesResult.rows[0]?.count || 1);
            const uptime = totalDevices > 0 ? ((activeDevices / totalDevices) * 100) : 0;

            const locationsResult = await pool.query(
                `SELECT COUNT(DISTINCT a) as count FROM sensor_data_aggregated WHERE a IS NOT NULL`
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
