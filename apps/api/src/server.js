// -------------------------------
// Imports & Configuration
// -------------------------------
const express = require('express');
const session = require('express-session');
const pg = require('pg');
const dotenv = require('dotenv');
const client = require('prom-client');
const cors = require('cors');

// Load environment variables (.env file)
dotenv.config();

// Route imports
const authRoutes = require('./routes/auth');
const apiRoutes = require('./routes/api');
const messageRoutes = require('./routes/messages');
const analyticsRoutes = require('./routes/analytics');
const finalSensorRoutes = require('./routes/finalSensors');

// -------------------------------
// Initialize Express App
// -------------------------------
const app = express();
const PORT = process.env.PORT || 8000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Trust the first proxy (Ingress/Nginx) to handle X-Forwarded-* headers correctly
app.set('trust proxy', 1);

// Enable CORS for frontend-to-API communication
app.use(cors({ origin: true, credentials: true }));

// Prometheus metrics registry for API/process and HTTP traffic.
const metricsRegister = new client.Registry();
metricsRegister.setDefaultLabels({ app: 'fire-api', env: NODE_ENV });
client.collectDefaultMetrics({ register: metricsRegister });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [metricsRegister]
});

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [metricsRegister]
});

// -------------------------------
// PostgreSQL Connection
// -------------------------------
const isProduction = NODE_ENV === 'production';
const sslMode = process.env.PGSSLMODE;

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: (isProduction && sslMode !== 'disable')
    ? { rejectUnauthorized: false }
    : false
});

// Test DB connection
pool.connect()
  .then(client => {
    console.log('✅ Connected to PostgreSQL database successfully');
    client.release();
  })
  .catch(err => {
    console.error('❌ PostgreSQL connection error:', err.message);
  });

// -------------------------------
// Middleware
// -------------------------------
const PgSession = require('connect-pg-simple')(session);

// Initialize session middleware early so downstream middleware (like Grafana auth) can access sessions
app.use(session({
  store: new PgSession({
    pool: pool,
    tableName: 'session',
    createTableIfMissing: true
  }),
  secret: process.env.SESSION_SECRET || 'super-secret-key',
  resave: false,
  saveUninitialized: false,
  proxy: true,
  cookie: {
    httpOnly: true,
    secure: process.env.COOKIE_SECURE === 'true' ? true : (process.env.COOKIE_SECURE === 'false' ? false : 'auto'),
    sameSite: process.env.COOKIE_SAMESITE || 'lax',
    maxAge: 24 * 60 * 60 * 1000
  }
}));

// Attach DB pool to each request
app.use((req, res, next) => {
  req.pool = pool;
  next();
});

// Prometheus HTTP metrics tracking middleware
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
    const routePath = req.route && req.route.path ? req.route.path : req.path;
    const route = `${req.baseUrl || ''}${routePath || ''}` || 'unknown';
    const labels = {
      method: req.method,
      route,
      status_code: String(res.statusCode)
    };

    httpRequestDuration.observe(labels, durationSeconds);
    httpRequestsTotal.inc(labels);
  });

  next();
});

// Debug: log signup paths
app.use((req, res, next) => {
  if (req.method === 'POST' && (req.originalUrl.includes('signup') || req.originalUrl.includes('login'))) {
    console.log(`[auth-debug] ${req.method} ${req.originalUrl}`);
  }
  next();
});

// -------------------------------
// Body Parsing & Middleware for standard API routes
// -------------------------------
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// -------------------------------
// Routes
// -------------------------------
app.use('/auth', authRoutes);
app.use('/api', apiRoutes);
app.use('/messages', messageRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/final-sensors', finalSensorRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('healthy');
});

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', metricsRegister.contentType);
    res.end(await metricsRegister.metrics());
  } catch (err) {
    console.error('Metrics endpoint error:', err.message);
    res.status(500).end('metrics_error');
  }
});

// -------------------------------
// Error Handling
// -------------------------------
app.use((err, req, res, next) => {
  console.error('Server error:', err.stack);
  res.status(500).send('Something went wrong!');
});

// -------------------------------
// Start Server
// -------------------------------
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://0.0.0.0:${PORT} (${NODE_ENV} mode)`);
});
