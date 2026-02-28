const express = require('express');
const { dbGet, dbAll, dbRun } = require('../config/database');
const { generateUploadUrl, generateDownloadUrl, deleteFile } = require('../services/storageService');

const router = express.Router();

const ALLOWED_CATEGORIES = ['documents', 'evidence', 'medical', 'identity', 'financial', 'general'];
const MAX_FILES_PER_USER = 500;

// ─── POST /api/vault/upload-url ─────────────────────────────────────────────
// Step 1 of upload: client requests a presigned B2 upload URL.
// Step 2: client uploads file directly to B2 using that URL.
// Step 3: client calls POST /api/vault/confirm-upload to save the metadata.
router.post('/upload-url', async (req, res) => {
    try {
        const userId = req.userId;
        const { fileName, category = 'general', contentType, fileSizeBytes, description } = req.body;

        if (!fileName || !fileSizeBytes) {
            return res.status(400).json({
                error: 'Validation Error',
                message: 'fileName and fileSizeBytes are required',
            });
        }
        if (!ALLOWED_CATEGORIES.includes(category)) {
            return res.status(400).json({
                error: 'Validation Error',
                message: `category must be one of: ${ALLOWED_CATEGORIES.join(', ')}`,
            });
        }

        // Enforce per-user file limit
        const countRow = await dbGet(
            'SELECT COUNT(*) AS count FROM vault_files WHERE user_id = $1',
            [userId]
        );
        if (parseInt(countRow?.count || 0, 10) >= MAX_FILES_PER_USER) {
            return res.status(429).json({
                error: 'Limit Reached',
                message: `Maximum ${MAX_FILES_PER_USER} files per user reached.`,
            });
        }

        // Fetch user info for metadata
        const user = await dbGet('SELECT name, email FROM users WHERE id = $1', [userId]);

        const fileId = `file_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

        const { uploadUrl, storageKey } = await generateUploadUrl(
            userId, category, fileId, fileName, contentType, fileSizeBytes
        );

        // Save pending metadata — marked uploaded_at = NULL until confirmed
        await dbRun(
            `INSERT INTO vault_files
                (id, user_id, username, email, file_name, original_name, category,
                 content_type, file_size_bytes, storage_key, description, uploaded_at, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NULL, $12)`,
            [
                fileId, userId, user.name, user.email,
                fileName, fileName, category,
                contentType || 'application/octet-stream',
                fileSizeBytes, storageKey, description || null,
                Date.now(),
            ]
        );

        res.json({
            message: 'Upload URL generated. Upload file to B2, then call /confirm-upload.',
            fileId,
            uploadUrl,
            expiresInSeconds: 900,
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── POST /api/vault/confirm-upload ─────────────────────────────────────────
// Called by the client AFTER successfully uploading to B2.
router.post('/confirm-upload', async (req, res) => {
    try {
        const userId = req.userId;
        const { fileId } = req.body;

        if (!fileId) {
            return res.status(400).json({ error: 'Validation Error', message: 'fileId is required' });
        }

        const file = await dbGet(
            'SELECT id FROM vault_files WHERE id = $1 AND user_id = $2',
            [fileId, userId]
        );
        if (!file) {
            return res.status(404).json({ error: 'Not Found', message: 'File not found' });
        }

        await dbRun(
            'UPDATE vault_files SET uploaded_at = $1 WHERE id = $2',
            [Date.now(), fileId]
        );

        const updated = await dbGet('SELECT * FROM vault_files WHERE id = $1', [fileId]);
        res.json({ message: 'File upload confirmed', file: updated });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── GET /api/vault/files ────────────────────────────────────────────────────
// List current user's uploaded files, optionally filtered by category.
router.get('/files', async (req, res) => {
    try {
        const userId = req.userId;
        const { category } = req.query;

        let query = `
            SELECT id, file_name, category, content_type, file_size_bytes,
                   description, uploaded_at, created_at
            FROM vault_files
            WHERE user_id = $1 AND uploaded_at IS NOT NULL`;
        const params = [userId];

        if (category) {
            query += ' AND category = $2';
            params.push(category);
        }
        query += ' ORDER BY created_at DESC';

        const files = await dbAll(query, params);
        res.json({ message: 'Vault files retrieved', files });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── POST /api/vault/download-url/:fileId ────────────────────────────────────
// Get a short-lived download URL for a specific file.
router.post('/download-url/:fileId', async (req, res) => {
    try {
        const userId = req.userId;
        const { fileId } = req.params;

        const file = await dbGet(
            'SELECT storage_key, file_name FROM vault_files WHERE id = $1 AND user_id = $2 AND uploaded_at IS NOT NULL',
            [fileId, userId]
        );
        if (!file) {
            return res.status(404).json({ error: 'Not Found', message: 'File not found' });
        }

        const downloadUrl = await generateDownloadUrl(file.storage_key);
        res.json({ message: 'Download URL generated', downloadUrl, fileName: file.file_name, expiresInSeconds: 3600 });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── GET /api/vault/usage ────────────────────────────────────────────────────
// Returns total storage used by the current user.
router.get('/usage', async (req, res) => {
    try {
        const userId = req.userId;

        const usageRow = await dbGet(
            `SELECT
                COUNT(*) AS file_count,
                COALESCE(SUM(file_size_bytes), 0) AS total_bytes
             FROM vault_files
             WHERE user_id = $1 AND uploaded_at IS NOT NULL`,
            [userId]
        );

        res.json({
            message: 'Storage usage retrieved',
            fileCount: parseInt(usageRow.file_count, 10),
            totalBytes: parseInt(usageRow.total_bytes, 10),
            totalMB: (parseInt(usageRow.total_bytes, 10) / (1024 * 1024)).toFixed(2),
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

// ─── DELETE /api/vault/files/:fileId ────────────────────────────────────────
router.delete('/files/:fileId', async (req, res) => {
    try {
        const userId = req.userId;
        const { fileId } = req.params;

        const file = await dbGet(
            'SELECT storage_key FROM vault_files WHERE id = $1 AND user_id = $2',
            [fileId, userId]
        );
        if (!file) {
            return res.status(404).json({ error: 'Not Found', message: 'File not found' });
        }

        // Delete from B2 first, then remove DB record
        await deleteFile(file.storage_key);
        await dbRun('DELETE FROM vault_files WHERE id = $1', [fileId]);

        res.json({ message: 'File deleted successfully' });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error', message: err.message });
    }
});

module.exports = router;
