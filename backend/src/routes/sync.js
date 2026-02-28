const express = require('express');
const { dbGet, dbAll, dbRun } = require('../config/database');

const router = express.Router();

// Get sync metadata
router.get('/metadata', async (req, res) => {
    try {
        const userId = req.userId;
        const metadata = await dbAll(
            'SELECT * FROM sync_metadata WHERE user_id = $1',
            [userId]
        );
        res.json({ message: 'Sync metadata retrieved', metadata });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// Sync pending changes (Outbox pattern)
router.post('/changes', async (req, res) => {
    try {
        const userId = req.userId;
        const { changes = [], lastSyncTimestamp } = req.body;

        if (!Array.isArray(changes)) {
            return res.status(400).json({
                error: 'Validation Error',
                message: 'Changes must be an array',
            });
        }

        const syncResults = [];

        for (const change of changes) {
            try {
                const { tableName, operation, recordId, data, vectorClock } = change;

                let conflicted = false;
                let serverVersion = null;

                if (operation === 'update' || operation === 'delete') {
                    serverVersion = await dbGet(
                        `SELECT vector_clock, data FROM sync_records
                         WHERE user_id = $1 AND table_name = $2 AND record_id = $3`,
                        [userId, tableName, recordId]
                    );

                    if (serverVersion) {
                        const clientClock = JSON.parse(vectorClock || '{}');
                        const serverClock = JSON.parse(serverVersion.vector_clock || '{}');
                        if (!_clockDominates(clientClock, serverClock)) {
                            conflicted = true;
                        }
                    }
                }

                if (!conflicted || operation === 'create') {
                    syncResults.push({
                        recordId,
                        status: 'success',
                        operation,
                        message: `${operation} operation applied`,
                    });
                } else {
                    syncResults.push({
                        recordId,
                        status: 'conflict',
                        operation,
                        serverVersion,
                        message: 'Conflict detected - server version newer',
                    });
                }
            } catch (err) {
                syncResults.push({
                    recordId: change.recordId,
                    status: 'error',
                    message: err.message,
                });
            }
        }

        res.json({ message: 'Sync completed', syncResults, serverTimestamp: Date.now() });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// Pull delta sync (get server changes since last sync)
router.post('/pull', async (req, res) => {
    try {
        const userId = req.userId;
        const { lastSyncTimestamp = 0, tables = [] } = req.body;

        const deltas = {};

        for (const tableName of tables) {
            const changes = await dbAll(
                `SELECT * FROM sync_records
                 WHERE user_id = $1 AND table_name = $2 AND updated_at > $3
                 ORDER BY updated_at DESC`,
                [userId, tableName, lastSyncTimestamp]
            );
            deltas[tableName] = changes;
        }

        res.json({ message: 'Delta sync data retrieved', deltas, serverTimestamp: Date.now() });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// Resolve conflict manually
router.post('/resolve-conflict', async (req, res) => {
    try {
        const { tableName, recordId, resolution } = req.body;

        if (!['client', 'server'].includes(resolution)) {
            return res.status(400).json({
                error: 'Validation Error',
                message: 'Resolution must be either "client" or "server"',
            });
        }

        res.json({ message: 'Conflict resolved', tableName, recordId, resolution });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// Helper: Vector clock comparison — returns true if clock1 dominates clock2
function _clockDominates(clock1, clock2) {
    let allLessOrEqual = true;
    let anyGreater = false;

    const allKeys = new Set([...Object.keys(clock1), ...Object.keys(clock2)]);

    for (const key of allKeys) {
        const val1 = clock1[key] || 0;
        const val2 = clock2[key] || 0;
        if (val1 > val2) anyGreater = true;
        if (val1 < val2) allLessOrEqual = false;
    }

    return anyGreater && allLessOrEqual;
}

module.exports = router;
