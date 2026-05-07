const { Pool } = require('pg');

const pool = new Pool({
  // Use ONLY the connection string for simplicity
  connectionString: process.env.DATABASE_URL,
  ssl: false
});

pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL successfully');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle client', err);
});

module.exports = pool;