// -------------------------------
// server.local.js - Local Dev Server
// -------------------------------

// Imports & Configuration
const express = require('express');
const session = require('express-session');
const path = require('path');
const pg = require('pg');
const dotenv = require('dotenv');

// Load environment variables (.env file)
dotenv.config();

// Route imports
const authRoutes = require('./routes/auth');
const apiRoutes = require('./routes/api');
const messageRoutes = require('./routes/messages');
const { ensureAuthenticated } = require('./middleware/auth');

const DASHBOARD_DIR = process.env.DASHBOARD_DIR || path.join(__dirname, '..', 'dashboard');

// -------------------------------
// Initialize Express App
// -------------------------------
const app = express();
const PORT = process.env.LOCAL_PORT || 8001; // Use a different port for local testing
const NODE_ENV = 'development'; // Force development mode

// -------------------------------
// PostgreSQL Connection (Local)
// -------------------------------
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false // Disable SSL for local dev
});

// Test DB connection
pool.connect()
  .then(client => {
    console.log('✅ Connected to PostgreSQL database (local)');
    client.release();
  })
  .catch(err => {
    console.error('❌ PostgreSQL connection error (local):', err.message);
  });

// -------------------------------
// Middleware
// -------------------------------
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.use(session({
  secret: 'local-dev-secret-key',
  resave: false,
  saveUninitialized: false
}));

// Attach DB pool to each request
app.use((req, res, next) => {
  req.pool = pool;
  next();
});

// Serve static files
app.use(express.static(DASHBOARD_DIR));

// -------------------------------
// Routes
// -------------------------------
app.use('/auth', authRoutes);
app.use('/api', apiRoutes);
app.use('/messages', messageRoutes);

// Root route
app.get('/', (req, res) => {
  if (req.session && req.session.user) {
    return res.redirect('/protected/dashboard.html');
  }
  return res.redirect('/login.html');
});

// Protect /protected pages
app.use('/protected', ensureAuthenticated);

app.get('/protected/:page', (req, res) => {
  const page = req.params.page;
  const pagePath = path.join(DASHBOARD_DIR, 'protected', page);
  res.sendFile(pagePath);
});

// Logout route
app.post('/logout', (req, res) => {
  req.session.destroy(err => {
    if (err) return res.status(500).send('Logout failed.');
    res.clearCookie('connect.sid');
    return res.redirect('/login.html?message=logout');
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err.stack);
  res.status(500).send('Something went wrong!');
});

// -------------------------------
// Start Local Server
// -------------------------------
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Local dev server running on http://0.0.0.0:${PORT}`);
});
