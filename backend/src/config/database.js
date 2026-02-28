const { Pool } = require('pg');

if (!process.env.DATABASE_URL) {
    console.error('❌ DATABASE_URL environment variable is not set.');
    process.exit(1);
}

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production'
        ? { rejectUnauthorized: false }
        : false,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
});

pool.on('connect', () => {
    console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
    console.error('❌ PostgreSQL pool error:', err.message);
});

/**
 * Execute a write query (INSERT, UPDATE, DELETE, CREATE).
 * Returns the pg result object (result.rows, result.rowCount, etc.)
 */
const dbRun = async (sql, params = []) => {
    const client = await pool.connect();
    try {
        const result = await client.query(sql, params);
        return result;
    } finally {
        client.release();
    }
};

/**
 * Fetch a single row. Returns undefined if no row found.
 */
const dbGet = async (sql, params = []) => {
    const result = await pool.query(sql, params);
    return result.rows[0];
};

/**
 * Fetch multiple rows. Returns an empty array if no rows found.
 */
const dbAll = async (sql, params = []) => {
    const result = await pool.query(sql, params);
    return result.rows;
};

module.exports = {
    pool,
    dbRun,
    dbGet,
    dbAll,
};
