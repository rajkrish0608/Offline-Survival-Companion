const { dbRun } = require('../config/database');

const migrations = [
    // Users table
    `CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    password_hash TEXT NOT NULL,
    created_at INTEGER,
    updated_at INTEGER
  )`,

    // Emergency contacts
    `CREATE TABLE IF NOT EXISTS emergency_contacts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    relationship TEXT,
    is_primary INTEGER DEFAULT 0,
    verified INTEGER DEFAULT 0,
    created_at INTEGER,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`,

    // Content packs
    `CREATE TABLE IF NOT EXISTS content_packs (
    id TEXT PRIMARY KEY,
    region_id TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT,
    size_mb INTEGER,
    version TEXT,
    filename TEXT,
    description TEXT,
    checksum TEXT,
    available INTEGER DEFAULT 1,
    last_updated INTEGER,
    created_at INTEGER
  )`,

    // First aid articles
    `CREATE TABLE IF NOT EXISTS first_aid_articles (
    id TEXT PRIMARY KEY,
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT,
    symptoms TEXT,
    treatment TEXT,
    precautions TEXT,
    severity TEXT,
    created_at INTEGER
  )`,

    // Emergency procedures
    `CREATE TABLE IF NOT EXISTS emergency_procedures (
    id TEXT PRIMARY KEY,
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    steps TEXT,
    duration_minutes INTEGER,
    created_at INTEGER
  )`,

    // POI regions
    `CREATE TABLE IF NOT EXISTS poi_regions (
    region_id TEXT PRIMARY KEY,
    region_name TEXT NOT NULL,
    bounds TEXT,
    poi_count INTEGER,
    created_at INTEGER
  )`,

    // Sync metadata
    `CREATE TABLE IF NOT EXISTS sync_metadata (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    table_name TEXT NOT NULL,
    last_sync INTEGER,
    vector_clock TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`,

    // Sync records (for conflict resolution)
    `CREATE TABLE IF NOT EXISTS sync_records (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id TEXT,
    data TEXT,
    vector_clock TEXT,
    updated_at INTEGER,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`,

    // Create indexes
    `CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON emergency_contacts(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_sync_metadata_user ON sync_metadata(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_sync_records_user ON sync_records(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_first_aid_category ON first_aid_articles(category)`,
];

const runMigrations = async () => {
    try {
        console.log('Running database migrations...');

        for (const migration of migrations) {
            await dbRun(migration);
        }

        console.log('✓ Database migrations completed successfully');
    } catch (err) {
        console.error('✗ Migration failed:', err.message);
        throw err;
    }
};

module.exports = { runMigrations };
