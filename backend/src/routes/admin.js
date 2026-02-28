/**
 * Admin API — Protected by ADMIN_API_KEY header.
 * Used for legal compliance, court orders, and internal admin access.
 *
 * All vault files in B2 are organized as:
 *   {userId}/{category}/{fileId}/{fileName}
 *
 * These endpoints allow admin to:
 *  - List all users and their vault file counts
 *  - Retrieve all files for a specific user (by username / email / userId)
 *  - Download any specific file
 *  - Delete a user's files
 */

const express = require('express');
const { dbGet, dbAll, dbRun } = require('../config/database');
const { generateDownloadUrl, deleteFile, listAdminObjects } = require('../services/storageService');

const router = express.Router();

// ── Admin auth middleware ────────────────────────────────────────────────────
router.use((req, res, next) => {
    const key = req.headers['x-admin-api-key'];
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'Forbidden', message: 'Invalid admin API key' });
    }
    next();
});

// ─── GET /api/admin/users ─────────────────────────────────────────────────
// List all registered users with their vault storage summary.
router.get('/users', async (req, res) => {
    try {
        const { search } = req.query;
        let query = `
            SELECT
                u.id,
                u.name,
                u.email,
                u.phone,
                u.created_at,
                COUNT(vf.id)                        AS file_count,
                COALESCE(SUM(vf.file_size_bytes), 0) AS total_bytes
            FROM users u
            LEFT JOIN vault_files vf ON vf.user_id = u.id AND vf.uploaded_at IS NOT NULL
        `;
        const params = [];

        if (search) {
            query += ' WHERE u.email ILIKE $1 OR u.name ILIKE $1';
            params.push(`%${search}%`);
        }

        query += ' GROUP BY u.id, u.name, u.email, u.phone, u.created_at ORDER BY u.created_at DESC';

        const users = await dbAll(query, params);
        res.json({ message: 'Users retrieved', totalUsers: users.length, users });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── GET /api/admin/users/:userId/files ───────────────────────────────────
// Get ALL vault files for a specific user, grouped/filtered by category.
// Used when responding to a court order for a specific user's stored evidence.
router.get('/users/:userId/files', async (req, res) => {
    try {
        const { userId } = req.params;
        const { category } = req.query;

        const user = await dbGet('SELECT id, name, email, phone FROM users WHERE id = $1', [userId]);
        if (!user) {
            return res.status(404).json({ error: 'Not Found', message: 'User not found' });
        }

        let query = `
            SELECT id, file_name, category, content_type, file_size_bytes,
                   storage_key, description, uploaded_at, created_at
            FROM vault_files
            WHERE user_id = $1 AND uploaded_at IS NOT NULL`;
        const params = [userId];

        if (category) {
            query += ' AND category = $2';
            params.push(category);
        }

        query += ' ORDER BY category ASC, created_at DESC';

        const files = await dbAll(query, params);

        // Group by category for easy reading
        const grouped = files.reduce((acc, file) => {
            if (!acc[file.category]) acc[file.category] = [];
            acc[file.category].push(file);
            return acc;
        }, {});

        res.json({
            message: 'User vault files retrieved',
            user: { id: user.id, name: user.name, email: user.email, phone: user.phone },
            totalFiles: files.length,
            byCategory: grouped,
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── POST /api/admin/users/:userId/files/:fileId/download-url ─────────────
// Generate a download URL for any specific file (admin-level access).
// Use this to retrieve evidence files for a court order.
router.post('/users/:userId/files/:fileId/download-url', async (req, res) => {
    try {
        const { userId, fileId } = req.params;

        const file = await dbGet(
            `SELECT vf.storage_key, vf.file_name, vf.category, u.name, u.email
             FROM vault_files vf
             JOIN users u ON u.id = vf.user_id
             WHERE vf.id = $1 AND vf.user_id = $2 AND vf.uploaded_at IS NOT NULL`,
            [fileId, userId]
        );

        if (!file) {
            return res.status(404).json({ error: 'Not Found', message: 'File not found' });
        }

        const downloadUrl = await generateDownloadUrl(file.storage_key);

        res.json({
            message: 'Admin download URL generated',
            downloadUrl,
            expiresInSeconds: 3600,
            file: {
                name: file.file_name,
                category: file.category,
                ownerName: file.name,
                ownerEmail: file.email,
            },
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── GET /api/admin/vault/by-email ───────────────────────────────────────
// Look up a user by email and return all their vault files.
// Useful when a court order specifies a username/email instead of an internal ID.
router.get('/vault/by-email', async (req, res) => {
    try {
        const { email } = req.query;
        if (!email) {
            return res.status(400).json({ error: 'Validation Error', message: 'email query param required' });
        }

        const user = await dbGet('SELECT id, name, email FROM users WHERE email ILIKE $1', [email]);
        if (!user) {
            return res.status(404).json({ error: 'Not Found', message: 'No user found with that email' });
        }

        const files = await dbAll(
            `SELECT id, file_name, category, content_type, file_size_bytes,
                    storage_key, description, uploaded_at, created_at
             FROM vault_files
             WHERE user_id = $1 AND uploaded_at IS NOT NULL
             ORDER BY category ASC, created_at DESC`,
            [user.id]
        );

        const grouped = files.reduce((acc, f) => {
            if (!acc[f.category]) acc[f.category] = [];
            acc[f.category].push(f);
            return acc;
        }, {});

        res.json({
            message: 'Vault files by email retrieved',
            user,
            totalFiles: files.length,
            byCategory: grouped,
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── GET /api/admin/vault/storage-summary ─────────────────────────────────
// Platform-wide stats: total files, total storage used, breakdown by category.
router.get('/vault/storage-summary', async (req, res) => {
    try {
        const summary = await dbAll(`
            SELECT
                category,
                COUNT(*)                             AS file_count,
                COALESCE(SUM(file_size_bytes), 0)   AS total_bytes
            FROM vault_files
            WHERE uploaded_at IS NOT NULL
            GROUP BY category
            ORDER BY total_bytes DESC
        `);

        const totals = await dbGet(`
            SELECT
                COUNT(DISTINCT user_id)             AS active_users,
                COUNT(*)                             AS total_files,
                COALESCE(SUM(file_size_bytes), 0)   AS total_bytes
            FROM vault_files
            WHERE uploaded_at IS NOT NULL
        `);

        res.json({
            message: 'Storage summary retrieved',
            totals: {
                activeUsers: parseInt(totals.active_users, 10),
                totalFiles: parseInt(totals.total_files, 10),
                totalBytes: parseInt(totals.total_bytes, 10),
                totalGB: (parseInt(totals.total_bytes, 10) / (1024 ** 3)).toFixed(3),
            },
            byCategory: summary,
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── DELETE /api/admin/users/:userId/files/:fileId ────────────────────────
// Admin delete — removes a file from B2 and the database.
router.delete('/users/:userId/files/:fileId', async (req, res) => {
    try {
        const { userId, fileId } = req.params;

        const file = await dbGet(
            'SELECT storage_key FROM vault_files WHERE id = $1 AND user_id = $2',
            [fileId, userId]
        );
        if (!file) {
            return res.status(404).json({ error: 'Not Found', message: 'File not found' });
        }

        await deleteFile(file.storage_key);
        await dbRun('DELETE FROM vault_files WHERE id = $1', [fileId]);

        res.json({ message: 'File deleted by admin' });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

module.exports = router;
