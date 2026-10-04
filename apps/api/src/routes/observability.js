const express = require('express');
const router = express.Router();
const { ensureAuthenticated } = require('../middleware/auth');

const PROM_URL = process.env.PROMETHEUS_URL || 'http://prometheus:9090';
const LOKI_URL = process.env.LOKI_URL || 'http://loki:3100';

router.use(ensureAuthenticated);

router.get('/metrics', async (req, res) => {
    try {
        const memReq = await fetch(`${PROM_URL}/api/v1/query?query=process_resident_memory_bytes`);
        const memData = await memReq.json();
        
        const cpuReq = await fetch(`${PROM_URL}/api/v1/query?query=rate(process_cpu_seconds_total[5m])`);
        const cpuData = await cpuReq.json();

        res.json({
            memory: memData?.data?.result || [],
            cpu: cpuData?.data?.result || []
        });
    } catch (err) {
        console.error("Prometheus error:", err);
        res.status(500).json({ error: "Failed to fetch metrics" });
    }
});

router.get('/logs/errors', async (req, res) => {
    try {
        const query = encodeURIComponent('{job="api"} |~ "(?i)error"');
        const lokiReq = await fetch(`${LOKI_URL}/loki/api/v1/query_range?query=${query}&limit=20`);
        const lokiData = await lokiReq.json();
        
        res.json({
            logs: lokiData?.data?.result || []
        });
    } catch (err) {
        console.error("Loki error:", err);
        res.status(500).json({ error: "Failed to fetch logs" });
    }
});

router.get('/app/metrics', async (req, res) => {
    try {
        const routeFilter = req.query.route === 'all' ? '.*' : req.query.route;
        
        const rpsQ = encodeURIComponent(`sum(rate(http_requests_total{route=~"${routeFilter}"}[5m]))`);
        const rpsReq = await fetch(`${PROM_URL}/api/v1/query?query=${rpsQ}`);
        const rpsData = await rpsReq.json();
        
        const start = Math.floor(Date.now()/1000) - 3600;
        const end = Math.floor(Date.now()/1000);
        const step = 60;
        const latencyQ = encodeURIComponent(`histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{route=~"${routeFilter}"}[5m])) by (le))`);
        const latencyReq = await fetch(`${PROM_URL}/api/v1/query_range?query=${latencyQ}&start=${start}&end=${end}&step=${step}`);
        const latencyData = await latencyReq.json();
        
        res.json({
            rps: rpsData?.data?.result || [],
            latency: latencyData?.data?.result || []
        });
    } catch (err) {
        console.error("App metrics error:", err);
        res.status(500).json({ error: "Failed to fetch app metrics" });
    }
});

router.get('/infra/health', async (req, res) => {
    try {
        const start = Math.floor(Date.now()/1000) - 3600;
        const end = Math.floor(Date.now()/1000);
        const step = 60;
        
        const cpuQ = encodeURIComponent(`100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`);
        const cpuReq = await fetch(`${PROM_URL}/api/v1/query_range?query=${cpuQ}&start=${start}&end=${end}&step=${step}`);
        const cpuData = await cpuReq.json();

        const memQ = encodeURIComponent(`100 * (1 - ((avg_over_time(node_memory_MemFree_bytes[5m]) + avg_over_time(node_memory_Cached_bytes[5m]) + avg_over_time(node_memory_Buffers_bytes[5m])) / avg_over_time(node_memory_MemTotal_bytes[5m])))`);
        const memReq = await fetch(`${PROM_URL}/api/v1/query_range?query=${memQ}&start=${start}&end=${end}&step=${step}`);
        const memData = await memReq.json();

        res.json({
            cpu: cpuData?.data?.result || [],
            memory: memData?.data?.result || []
        });
    } catch (err) {
        console.error("Infra health error:", err);
        res.status(500).json({ error: "Failed to fetch infra health" });
    }
});

router.get('/data/health', async (req, res) => {
    try {
        const start = Math.floor(Date.now()/1000) - 3600;
        const end = Math.floor(Date.now()/1000);
        const step = 60;

        const mqttQ = encodeURIComponent(`sum(broker_subscriptions_count)`);
        const mqttReq = await fetch(`${PROM_URL}/api/v1/query_range?query=${mqttQ}&start=${start}&end=${end}&step=${step}`);
        const mqttData = await mqttReq.json();

        const pgQ = encodeURIComponent(`sum(pg_stat_activity_count{state="active"})`);
        const pgReq = await fetch(`${PROM_URL}/api/v1/query_range?query=${pgQ}&start=${start}&end=${end}&step=${step}`);
        const pgData = await pgReq.json();

        res.json({
            mqtt: mqttData?.data?.result || [],
            postgres: pgData?.data?.result || []
        });
    } catch (err) {
        console.error("Data health error:", err);
        res.status(500).json({ error: "Failed to fetch data health" });
    }
});

module.exports = router;
