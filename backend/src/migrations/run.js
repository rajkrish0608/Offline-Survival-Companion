const { runMigrations } = require('./001_initial_schema');

const run = async () => {
    try {
        await runMigrations();
        process.exit(0);
    } catch (err) {
        console.error('Migration error:', err);
        process.exit(1);
    }
};

if (require.main === module) {
    run();
}

module.exports = { run };
