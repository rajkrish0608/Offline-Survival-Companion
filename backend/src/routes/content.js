const express = require('express');
const { dbGet, dbAll } = require('../config/database');

const router = express.Router();

// Get all available content packs
router.get('/packs', async (req, res) => {
    try {
        const packs = await dbAll(`
      SELECT 
        id, 
        region_id, 
        name, 
        type, 
        size_mb, 
        version,
        last_updated,
        description,
        checksum
      FROM content_packs
      WHERE available = 1
      ORDER BY name ASC
    `);

        res.json({
            message: 'Content packs retrieved successfully',
            packs,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Get pack details
router.get('/packs/:packId', async (req, res) => {
    try {
        const { packId } = req.params;

        const pack = await dbGet(`
      SELECT * FROM content_packs WHERE id = ?
    `, [packId]);

        if (!pack) {
            return res.status(404).json({
                error: 'Not Found',
                message: 'Pack not found',
            });
        }

        res.json({
            message: 'Pack details retrieved successfully',
            pack,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Get first aid database
router.get('/first-aid', async (req, res) => {
    try {
        const { category, search } = req.query;

        let query = 'SELECT * FROM first_aid_articles WHERE 1=1';
        const params = [];

        if (category) {
            query += ' AND category = ?';
            params.push(category);
        }

        if (search) {
            query += ' AND (title LIKE ? OR content LIKE ?)';
            const searchTerm = `%${search}%`;
            params.push(searchTerm, searchTerm);
        }

        const articles = await dbAll(query, params);

        res.json({
            message: 'First aid articles retrieved successfully',
            articles,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Get emergency procedures
router.get('/procedures', async (req, res) => {
    try {
        const procedures = await dbAll(`
      SELECT * FROM emergency_procedures
      ORDER BY category ASC
    `);

        res.json({
            message: 'Procedures retrieved successfully',
            procedures,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Get POI regions (for maps)
router.get('/poi-regions', async (req, res) => {
    try {
        const regions = await dbAll(`
      SELECT DISTINCT 
        region_id,
        region_name,
        bounds,
        poi_count
      FROM poi_regions
      ORDER BY region_name ASC
    `);

        res.json({
            message: 'POI regions retrieved successfully',
            regions,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Get download URL for pack
router.get('/packs/:packId/download-url', async (req, res) => {
    try {
        const { packId } = req.params;

        const pack = await dbGet(`
      SELECT * FROM content_packs WHERE id = ?
    `, [packId]);

        if (!pack) {
            return res.status(404).json({
                error: 'Not Found',
                message: 'Pack not found',
            });
        }

        // Generate pre-signed URL or direct download link
        const downloadUrl = `${process.env.CDN_BASE_URL || 'https://cdn.offline-survival.app'}/packs/${packId}/${pack.filename}`;

        res.json({
            message: 'Download URL generated',
            downloadUrl,
            pack: {
                id: pack.id,
                name: pack.name,
                size: pack.size_mb,
                checksum: pack.checksum,
                version: pack.version,
            },
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

module.exports = router;
