const { dbRun } = require('../config/database');

const migrations = [
    // Users table
    `CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        password_hash TEXT NOT NULL,
        created_at BIGINT,
        updated_at BIGINT
    )`,

    // Emergency contacts
    `CREATE TABLE IF NOT EXISTS emergency_contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relationship TEXT,
        is_primary BOOLEAN DEFAULT FALSE,
        verified BOOLEAN DEFAULT FALSE,
        created_at BIGINT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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
        available BOOLEAN DEFAULT TRUE,
        last_updated BIGINT,
        created_at BIGINT
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
        created_at BIGINT
    )`,

    // Emergency procedures
    `CREATE TABLE IF NOT EXISTS emergency_procedures (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        steps TEXT,
        duration_minutes INTEGER,
        created_at BIGINT
    )`,

    // POI regions
    `CREATE TABLE IF NOT EXISTS poi_regions (
        region_id TEXT PRIMARY KEY,
        region_name TEXT NOT NULL,
        bounds TEXT,
        poi_count INTEGER,
        created_at BIGINT
    )`,

    // Sync metadata
    `CREATE TABLE IF NOT EXISTS sync_metadata (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        last_sync BIGINT,
        vector_clock TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`,

    // Sync records (for conflict resolution)
    `CREATE TABLE IF NOT EXISTS sync_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT,
        data TEXT,
        vector_clock TEXT,
        updated_at BIGINT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`,

    // Vault files — stores file metadata + the storage path on Backblaze B2.
    // Files are organized as: {userId}/{category}/{fileId}/{originalFileName}
    // Vault files — stores file metadata + the storage path on Backblaze B2.
    // Files are organized as: {userId}/{category}/{fileId}/{originalFileName}
    // Admin can retrieve any user's files by userId/category for legal compliance.
    `CREATE TABLE IF NOT EXISTS vault_files (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        file_name TEXT NOT NULL,
        original_name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'general',
        content_type TEXT,
        file_size_bytes BIGINT NOT NULL DEFAULT 0,
        storage_key TEXT NOT NULL,
        description TEXT,
        uploaded_at BIGINT,
        created_at BIGINT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`,

    // Cloud-synced SOS Logs for Admin Dashboard
    `CREATE TABLE IF NOT EXISTS sos_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        timestamp TEXT NOT NULL,
        created_at BIGINT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`,

    // Indexes
    `CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user    ON emergency_contacts(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_sync_metadata_user         ON sync_metadata(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_sync_records_user          ON sync_records(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_first_aid_category         ON first_aid_articles(category)`,
    `CREATE INDEX IF NOT EXISTS idx_vault_files_user           ON vault_files(user_id)`,
    `CREATE INDEX IF NOT EXISTS idx_vault_files_category       ON vault_files(user_id, category)`,
    `CREATE INDEX IF NOT EXISTS idx_vault_files_email          ON vault_files(email)`,
    `CREATE INDEX IF NOT EXISTS idx_sos_logs_user              ON sos_logs(user_id)`,
];

const runMigrations = async () => {
    try {
        console.log('Running database migrations...');
        for (const migration of migrations) {
            await dbRun(migration);
        }
        console.log('✅ Database migrations completed successfully');
    } catch (err) {
        console.error('❌ Migration failed:', err.message);
        throw err;
    }
};

module.exports = { runMigrations };
